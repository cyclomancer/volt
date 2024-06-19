import React, { createContext, useContext, useEffect, useRef, useState } from 'react';
import BitcoinAmount from '../types/BitcoinAmount';
import { ApiContext } from './ApiContext';
import { FeedbackContext } from './FeedbackContext';
import { HotWalletFeeScryResponse } from '../types/Response';

interface HotWalletContextValue {
  hotWalletFee: BitcoinAmount | null;
};

export const HotWalletContext = createContext<HotWalletContextValue>({
  hotWalletFee: null,
});

export const HotWalletContextProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const api = useContext(ApiContext);
  const { displayJsError, displayJsSuccess } = useContext(FeedbackContext);
  const scryInProgress = useRef(false);
  const [hotWalletFee, setHotWalletFee] = useState<BitcoinAmount | null>(null);

  useEffect(() => {
    const getHotWalletFee = async () => {
      if (scryInProgress.current) return;
      scryInProgress.current = true;
      try {
        const response: HotWalletFeeScryResponse = await api.scry({
          app: "volt",
          path: "/hot-wallet-fee",
        });
        scryInProgress.current = false;
        displayJsSuccess("Scry /hot-wallet-fee succeeded");
        if (response.sats === null) {
          setHotWalletFee(null);
        } else {
          setHotWalletFee(BitcoinAmount.fromSatoshis(response.sats));
        }
      } catch (e) {
        scryInProgress.current = false;
        console.error(e);
        displayJsError("Scry /hot-wallet-fee failed")
        return null;
      }
    }
    getHotWalletFee()
  }, []);

  const value: HotWalletContextValue  = {
    hotWalletFee
  }

  return (
    <HotWalletContext.Provider value={value}>
      {children}
    </HotWalletContext.Provider>
  );
};
