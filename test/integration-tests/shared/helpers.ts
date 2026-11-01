import { BigNumber } from 'ethers'
import bn from 'bignumber.js'

export function expandTo18DecimalsBN(n: number): BigNumber {
  // 中间过程使用 bn，以便在中间计算中允许小数
  return BigNumber.from(new bn(n).times(new bn(10).pow(18)).toFixed())
}

export function expandTo6DecimalsBN(n: number): BigNumber {
  // 中间过程使用 bn，以便在中间计算中允许小数
  return BigNumber.from(new bn(n).times(new bn(10).pow(6)).toFixed())
}
