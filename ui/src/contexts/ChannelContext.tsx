import React, { createContext, useState, useEffect, useContext, useMemo, useRef} from 'react';
import Channel, { ChannelId, ChannelJson, ChannelStatus, FundingAddress, TauAddress } from '../types/Channel';
import { FeedbackContext } from './FeedbackContext';
import { ApiContext } from './ApiContext';
import BitcoinAmount from '../types/BitcoinAmount';
import {
  TempChanUpgradedUpdate,
  ChannelStateUpdate,
  InitialStateUpdate,
  NewChannelUpdate,
  Update,
  UpdateType,
  NeedFundingUpdate
} from '../types/Update';

interface ChannelContextValue {
  inboundCapacity: BitcoinAmount;
  outboundCapacity: BitcoinAmount;
  channels: Array<Channel>;
  channelsByStatus: {
    preopening: Channel[];
    opening: Channel[];
    funded: Channel[];
    open: Channel[];
    shutdown: Channel[];
    closing: Channel[];
    "force-closing": Channel[];
    closed: Channel[];
    redeemed: Channel[];
  };
  preopeningChannels: Channel[];
  tauAddressByTempChanId: Record<ChannelId, TauAddress>;
  fundingAddressByTempChanId: Record<ChannelId, FundingAddress>;
}

export const ChannelContext = createContext<ChannelContextValue>({
  inboundCapacity: new BitcoinAmount(0),
  outboundCapacity: new BitcoinAmount(0),
  channels: [],
  channelsByStatus: {
    preopening: [],
    opening: [],
    funded: [],
    open: [],
    shutdown: [],
    closing: [],
    "force-closing": [],
    closed: [],
    redeemed: [],
  },
  preopeningChannels: [],
  tauAddressByTempChanId: {},
  fundingAddressByTempChanId: {},
});

export const ChannelContextProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const api = useContext(ApiContext);
  const { displayJsInfo, displayJsSuccess, displayJsError } = useContext(FeedbackContext);

  const [channels, setChannels] = useState<Array<Channel>>([]);
  const [tauAddressByTempChanId, setTauAddressByTempChanId] = useState({});
  const [fundingAddressByTempChanId, setFundingAddressByTempChanId] = useState({});

  // currently subscribed or attempting to subscribe
  const activeSubscription = useRef(false);
  // subscribed and have received an update
  const subscriptionSuccessful = useRef(false);

  const channelsByStatus = useMemo(() => {
    return channels.reduce(
      (acc: { [key in ChannelStatus]: Channel[] }, channel) => {
        const status = channel.status;
        acc[status].push(channel);
        return acc;
      },
      {
        preopening: [],
        opening: [],
        funded: [],
        open: [],
        shutdown: [],
        closing: [],
        "force-closing": [],
        closed: [],
        redeemed: [],
      } as { [key in ChannelStatus]: Channel[] }
    );
  }, [channels]);

  const preopeningChannels = useMemo(() => {
    return channelsByStatus.preopening;
  }, [channelsByStatus]);

  useEffect(() => {
    const handleAllUpdate = (update: Update) => {
      if (!subscriptionSuccessful.current) {
        subscriptionSuccessful.current = true;
        displayJsSuccess('Subscription to /all succeeded');
      }
      if (update.type === UpdateType.NeedFunding) {
        displayJsInfo('Got need funding update from /all');
        handleNeedFunding(update as NeedFundingUpdate)
      } else if (update.type === UpdateType.InitialState) {
        displayJsInfo('Got initial state update from /all');
        handleInitialState(update as InitialStateUpdate);
      } else if (update.type === UpdateType.ChannelState) {
        displayJsInfo('Got channel state update from /all');
        handleChannelUpdate(update as ChannelStateUpdate);
      } else if (update.type === UpdateType.NewChannel) {
        displayJsInfo('Got new channel update from /all');
        handleNewChannel(update as NewChannelUpdate);
      } else if (update.type === UpdateType.TempChanUpgraded) {
        displayJsInfo('Got channel upgraded update from /all');
        handleTemporaryChannelUpgraded(update as TempChanUpgradedUpdate);
      } else {
        console.log('Unimplemented update type', update);
      }
    }

    const handleNeedFunding = (update: NeedFundingUpdate) => {
      const fundingInfo = update['funding-info'];
      let newTauAddressByTempChanId: Record<ChannelId, TauAddress> = {};
      let newFundingAddressByTempChanId: Record<ChannelId, FundingAddress> = {};
      fundingInfo.forEach((info) => {
        newTauAddressByTempChanId[info['temporary-channel-id']] = info['tau-address'];
        newFundingAddressByTempChanId[info['temporary-channel-id']] = info['funding-address'];
      });
      setTauAddressByTempChanId(prevState => ({
        ...prevState,
        ...newTauAddressByTempChanId
      }));
      setFundingAddressByTempChanId(prevState => ({
        ...prevState,
        ...newFundingAddressByTempChanId
      }));
    }

    const handleChannelUpdate = (update: ChannelStateUpdate) => {
      const { id, status }: { id: string, status: ChannelStatus } = update;
      if (!id || !status) return;
      return setChannels((channels) => {
        const channel = channels.find((channel) => channel.id === id);
        if (!channel) {
          console.error('Channel not found in update from /all', update);
          return channels;
        }
        channel.status = status;
        return [...channels];
      })
    }

    const handleNewChannel = (update: NewChannelUpdate) => {
      const { 'chan-info': jsonChan }: { 'chan-info': ChannelJson } = update;
      setChannels((channels) => {
        if (channels.find((channel) => channel.id === jsonChan.id)) return channels;
        const channel = {
          ...jsonChan,
          his: new BitcoinAmount(jsonChan.his),
          our: new BitcoinAmount(jsonChan.our),
        };
        return [...channels, channel];
      });
    }

    const handleTemporaryChannelUpgraded = (update: TempChanUpgradedUpdate) => {
      const { id }: { id: string } = update;
      setChannels((channels) => {
        const channel = channels.find((channel) => channel.id === id);
        if (!channel) return channels;
        return channels.filter((channel) => channel.id !== id);
      })
    }

    const handleInitialState = (update: InitialStateUpdate) => {
      const { chans: jsonChans }: { 'chans': Array<ChannelJson> } = update;
      const channels: Array<Channel> = jsonChans.map((chan) => {
        return {
          ...chan,
          his: new BitcoinAmount(chan.his),
          our: new BitcoinAmount(chan.our),
        }
      });
      setChannels(channels);
    };

    const subscribe = () => {
      if (activeSubscription.current) return;
      try {
        api.subscribe({
          app: "volt",
          path: "/all",
          event: (e) => {
            handleAllUpdate(e);
          },
          err: () => {
            displayJsError("Subscription to /all rejected")
            activeSubscription.current = false;
            subscriptionSuccessful.current = false;
          },
          quit: () => {
            displayJsError("Kicked from subscription to /all")
            activeSubscription.current = false;
            subscriptionSuccessful.current = false;
          },
        });
        activeSubscription.current = true;
      } catch (e) {
        console.error(e)
        displayJsError("Error subscribing to /all"),
        activeSubscription.current = false;
        subscriptionSuccessful.current = false;
      }
    };
    subscribe()
  }, [])

  const inboundCapacity = useMemo(() => {
    return channelsByStatus.open?.reduce(
      (total, channel) => total.add(channel.his), new BitcoinAmount(0)
    );
  }, [channelsByStatus]);

  const outboundCapacity = useMemo(() => {
    return channelsByStatus.open?.reduce(
      (total, channel) => total.add(channel.our), new BitcoinAmount(0)
    );
  }, [channelsByStatus]);

  const value = {
    channels,
    channelsByStatus,
    inboundCapacity,
    outboundCapacity,
    preopeningChannels,
    tauAddressByTempChanId,
    fundingAddressByTempChanId,
  };

  return (
    <ChannelContext.Provider value={value}>
      {children}
    </ChannelContext.Provider>
  );
};
