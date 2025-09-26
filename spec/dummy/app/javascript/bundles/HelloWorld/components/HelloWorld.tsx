import * as React from 'react'
import { useState, useEffect } from 'react'
import type { FunctionComponent } from 'react'

import style from './HelloWorld.module.css'
import logo from './logo.svg'

export interface Props {
  readonly name: string
}

// Note, you need to declare the `FunctionComponent` type so that it complies
// with `ReactOnRails.register` type.
const HelloWorld: FunctionComponent<Props> = (props: Props) => {
  const [name, setName] = useState(props.name)

  useEffect(() => {
    console.log(
      '%c%s%c%s',
      'color: green; background-color: lightgreen; font-weight: bold;',
      'ShakaCode is hiring!',
      'color: green; background-color: lightgreen; font-weight: normal;',
      'Check out our open positions: https://www.shakacode.com/career/',
    );
  }, [])

  return (
    <>
      <img src={logo} className={style.logo} alt="logo" />
      <h3>Hello, {name || 'World'}!</h3>
      <hr />
      <form>
        <label className={style.bright} htmlFor="name">
          Say hello to:{' '}
          <input
            id="name"
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
      </form>
    </>
  )
}

export default HelloWorld
