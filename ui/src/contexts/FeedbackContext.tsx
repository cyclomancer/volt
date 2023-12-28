import React, { createContext, useState } from 'react';
import FeedbackConsoleLine from '../components/feedback/FeedbackConsoleLine';
import Command from '../types/Command';

interface FeedbackContextValue {
  displayCommandSuccess: (command: Command) => void;
  displayCommandError: (command: Command, text: string) => void;
  displayJsSuccess: (text: string) => void;
  displayJsInfo: (text: string) => void;
  displayJsError: (text: string) => void;
  lines: Array<React.JSX.Element>;
}

// Create the context
export const FeedbackContext = createContext<FeedbackContextValue>({
  displayCommandSuccess: () => {},
  displayCommandError: () => {},
  displayJsSuccess: () => {},
  displayJsInfo: () => {},
  displayJsError: () => {},
  lines: [],
});

export const FeedbackContextProvider: React.FC<{ children: React.ReactNode }> = ({ children })  => {
  const defaultLine = <FeedbackConsoleLine isError={false} isSuccess={false} text={'Volt 1.0 UI Log ⚡'} />
  const [lines, setLines] = useState<Array<React.JSX.Element>>([defaultLine]);

  const displayCommandSuccess = (command: Command): void => {
    const text = `[JS]: %${command} succeeded ✅`;
    const newLine = <FeedbackConsoleLine isError={false} isSuccess={true} text={text} />
    setLines([...lines, newLine]);
  }

  const displayCommandError = (command: Command, text: string): void => {
    const newLines = text.split('\n').filter(line => line.length).map(line => {
      return <FeedbackConsoleLine isError={false} isSuccess={false} text={`[Urbit]: ${line}`} />
    })
    newLines.push(
      <FeedbackConsoleLine isError={true} isSuccess={false} text={`[JS]: %${command} failed`} />
    )
    setLines([...lines, ...newLines]);
  }

  const displayJsSuccess = (text: string): void => {
    text = `[JS]: ${text} ✅`;
    const line = <FeedbackConsoleLine isError={false} isSuccess={true} text={text} />
    setLines([...lines, line]);
  }

  const displayJsInfo = (text: string): void => {
    text = `[JS]: ${text}`;
    const newLine = <FeedbackConsoleLine isError={false} isSuccess={false} text={text} />
    setLines([...lines, newLine]);
  }

  const displayJsError = (text: string): void => {
    text = `[JS]: ${text} ❌`;
    const line = <FeedbackConsoleLine isError={true} isSuccess={false} text={text} />
    setLines([...lines, line]);
  }

  const value = {
    displayCommandSuccess,
    displayCommandError,
    displayJsSuccess,
    displayJsInfo,
    displayJsError,
    lines,
  };

  return (
    <FeedbackContext.Provider value={value}>
      {children}
    </FeedbackContext.Provider>
  );
};
