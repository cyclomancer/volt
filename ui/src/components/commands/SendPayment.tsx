import React, { useState, useContext, useMemo } from 'react';
import Urbit from '@urbit/http-api';
import { isValidPatp, preSig } from '@urbit/aura'
import Button from './shared/Button';
import { FeedbackContext } from '../../contexts/FeedbackContext';
import Command from '../../types/Command';
import Input from './shared/Input';
import CommandForm from './shared/CommandForm';
import BitcoinAmount from '../../types/BitcoinAmount';
import Text from './shared/Text';
import { PayreqAmountScryResponse } from '../../types/Response';

type DecodedPayreqAmountScryResponse = {
  amount: BitcoinAmount | null,
  isValid: boolean
}

const SendPayment = ({ api }: { api: Urbit }) => {
  const { displayCommandSuccess, displayCommandError, displayJsError, displayJsSuccess } = useContext(FeedbackContext);

  const [payreq, setPayreq] = useState('');
  const [payreqValid, setPayreqValid] = useState<boolean | null>(null);
  const [payreqAmount, setPayreqAmount] = useState<BitcoinAmount | null>(null);
  const [shipInput, setShipInput] = useState('~');
  const [ship, setShip] = useState<string | null>(null);

  const getPayreqAmount = async (invoiceString: string): Promise<DecodedPayreqAmountScryResponse> => {
    try {
      const response: PayreqAmountScryResponse = await api.scry({
        app: "volt",
        path: `/utils/payreq/amount/${invoiceString}`,
      });
      displayJsSuccess(`Scry /utils/payreq/amount succeeded`);
      const amount = (response.msats === null) ? null : new BitcoinAmount(response.msats);
      return { amount, isValid: response['is-valid'] };
    } catch (e) {
      console.error(e);
      displayJsError(`Scry /utils/payreq/amount failed`);
      throw e;
    }
  }

  const onChangePayreq = async (e: React.ChangeEvent<HTMLInputElement>) => {
    setPayreq(e.target.value);
    if (e.target.value === '') {
      setPayreqValid(null);
      setPayreqAmount(null);
      return;
    }
    try {
      const { amount, isValid } = await getPayreqAmount(e.target.value);
      setPayreqAmount(amount);
      setPayreqValid(isValid);
    } catch (e) {
      setPayreqValid(null);
      setPayreqAmount(null);
    }
  };

  const onChangeShipInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    setShipInput(e.target.value);
    if (isValidPatp(preSig(e.target.value))) {
      setShip(preSig(e.target.value));
    } else {
      setShip(null);
    }
  };

  const sendPayment =  (e: React.FormEvent) => {
    e.preventDefault();
    if (!payreq || !payreqValid  || !payreqAmount) {
      displayJsError("Payreq required");
      return;
    }
    try {
      api.poke({
        app: "volt",
        mark: "volt-command",
        json: {
          "send-payment": {
            payreq: payreq,
            who: ship
          }
        },
        onSuccess: () => displayCommandSuccess(Command.SendPayment),
        onError: (e) => displayCommandError(Command.SendPayment, e),
      });
    } catch (e) {
      displayJsError('Error sending payment');
      console.error(e);
    }
  };

  const payreqText: string | null = useMemo(() => {
  let text = 'Amount: ~';
  if (payreqValid === true) {
    if (payreqAmount) {
      text = `Amount: ${payreqAmount.displayAsSats()}`;
    } else {
      text = `Payreq doesn't specify amount`;
    }
  } else if (payreqValid === false) {
    text = 'Payreq is invalid';
  }
  return text;
  }, [payreqValid, payreqAmount]);

  return (
    <CommandForm>
      <Input
        label={"Payreq"}
        value={payreq}
        onChange={onChangePayreq}
      />
      {payreqText ? <Text className='py-2' text={payreqText} /> : null}
      <Input
        label={"Ship (optional)"}
        value={shipInput}
        onChange={onChangeShipInput}
      />
      <Button onClick={sendPayment} label={'Send Payment'}/>
    </CommandForm>
  );
};

export default SendPayment;
