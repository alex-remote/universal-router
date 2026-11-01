import type { Contract } from '@ethersproject/contracts'
import { Pair } from '@uniswap/v2-sdk'
import { expect } from './shared/expect'
import { BigNumber } from 'ethers'
import { IPermit2, PoolManager, PositionManager, UniversalRouter } from '../../typechain'
import { abi as TOKEN_ABI } from '../../artifacts/solmate/src/tokens/ERC20.sol/ERC20.json'
import { resetFork, WETH, DAI, USDC, USDT, PERMIT2 } from './shared/mainnetForkHelpers'
import {
  ADDRESS_THIS,
  ALICE_ADDRESS,
  CONTRACT_BALANCE,
  DEADLINE,
  ETH_ADDRESS,
  MAX_UINT,
  MAX_UINT160,
  MSG_SENDER,
  OPEN_DELTA,
  SOURCE_MSG_SENDER,
  SOURCE_ROUTER,
} from './shared/constants'
import { expandTo18DecimalsBN, expandTo6DecimalsBN } from './shared/helpers'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import deployUniversalRouter from './shared/deployUniversalRouter'
import { RoutePlanner, CommandType } from './shared/planner'
import hre from 'hardhat'
import { getPermitBatchSignature } from './shared/protocolHelpers/permit2'
import { encodePathExactInput, encodePathExactOutput } from './shared/swapRouter02Helpers'
import { executeRouter } from './shared/executeRouter'
import { Actions, V4Planner } from './shared/v4Planner'
import {
  addLiquidityToV4Pool,
  DAI_USDC,
  deployV4PoolManager,
  encodeMultihopExactInPath,
  ETH_USDC,
  initializeV4Pool,
  USDC_WETH,
} from './shared/v4Helpers'
const { ethers } = hre

describe('Uniswap V2, V3, and V4 Tests:', () => {
  let alice: SignerWithAddress
  let bob: SignerWithAddress
  let router: UniversalRouter
  let permit2: IPermit2
  let daiContract: Contract
  let wethContract: Contract
  let usdcContract: Contract
  let planner: RoutePlanner
  let v4Planner: V4Planner
  let v4PoolManager: PoolManager
  let v4PositionManager: PositionManager

  // 该区块时 ETH 的当前市场价格
  const USD_ETH_PRICE = 3820

  beforeEach(async () => {
    await resetFork()
    await hre.network.provider.request({
      method: 'hardhat_impersonateAccount',
      params: [ALICE_ADDRESS],
    })
    alice = await ethers.getSigner(ALICE_ADDRESS)
    bob = (await ethers.getSigners())[1]
    daiContract = new ethers.Contract(DAI.address, TOKEN_ABI, bob)
    wethContract = new ethers.Contract(WETH.address, TOKEN_ABI, bob)
    usdcContract = new ethers.Contract(USDC.address, TOKEN_ABI, bob)
    permit2 = PERMIT2.connect(bob) as IPermit2

    v4PoolManager = (await deployV4PoolManager(bob.address)).connect(bob) as PoolManager
    router = (await deployUniversalRouter(undefined, v4PoolManager.address)).connect(bob) as UniversalRouter

    v4PositionManager = (await ethers.getContractAt('PositionManager', await router.V4_POSITION_MANAGER())).connect(
      bob
    ) as PositionManager
    planner = new RoutePlanner()
    v4Planner = new V4Planner()

    // alice 给 bob 转一些代币
    await daiContract.connect(alice).transfer(bob.address, expandTo18DecimalsBN(1000000))
    await wethContract.connect(alice).transfer(bob.address, expandTo18DecimalsBN(1000))
    await usdcContract.connect(alice).transfer(bob.address, expandTo6DecimalsBN(50000000))

    // Bob 给 permit2 合约最大授权，使其可动用他的 DAI 和 WETH
    await daiContract.connect(bob).approve(permit2.address, MAX_UINT)
    await wethContract.connect(bob).approve(permit2.address, MAX_UINT)
    await usdcContract.connect(bob).approve(permit2.address, MAX_UINT)

    // 在这些测试中，Bob 在 permit2 上给路由器最大授权
    await permit2.approve(DAI.address, router.address, MAX_UINT160, DEADLINE)
    await permit2.approve(WETH.address, router.address, MAX_UINT160, DEADLINE)
    await permit2.approve(USDC.address, router.address, MAX_UINT160, DEADLINE)

    // 为了设置池，bob 在 permit2 上给 position manager 授权
    await permit2.approve(DAI.address, v4PositionManager.address, MAX_UINT160, DEADLINE)
    await permit2.approve(WETH.address, v4PositionManager.address, MAX_UINT160, DEADLINE)
    await permit2.approve(USDC.address, v4PositionManager.address, MAX_UINT160, DEADLINE)

    // bob 初始化 3 个 v4 池
    await initializeV4Pool(v4PoolManager, USDC_WETH.poolKey, USDC_WETH.price)
    await initializeV4Pool(v4PoolManager, DAI_USDC.poolKey, DAI_USDC.price)
    await initializeV4Pool(v4PoolManager, ETH_USDC.poolKey, ETH_USDC.price)

    // bob 向这些池添加流动性
    await addLiquidityToV4Pool(v4PositionManager, USDC_WETH, expandTo18DecimalsBN(2).toString(), bob)
    await addLiquidityToV4Pool(v4PositionManager, DAI_USDC, expandTo18DecimalsBN(400).toString(), bob)
    await addLiquidityToV4Pool(v4PositionManager, ETH_USDC, expandTo18DecimalsBN(0.1).toString(), bob)
  })

  describe('Interleaving routes', () => {
    it('V3, then V2', async () => {
      const v3Tokens = [DAI.address, USDC.address]
      const v2Tokens = [USDC.address, WETH.address]
      const v3AmountIn: BigNumber = expandTo18DecimalsBN(5)
      const v3AmountOutMin = 0
      const v2AmountOutMin = expandTo18DecimalsBN(0.0005)

      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        Pair.getAddress(USDC, WETH),
        v3AmountIn,
        v3AmountOutMin,
        encodePathExactInput(v3Tokens),
        SOURCE_MSG_SENDER,
        [],
      ])
      // amountIn 为 0，因为 USDC 已经在交易对中
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [MSG_SENDER, 0, v2AmountOutMin, v2Tokens, SOURCE_MSG_SENDER, []])

      const { wethBalanceBefore, wethBalanceAfter, v2SwapEventArgs } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      const { amount1Out: wethTraded } = v2SwapEventArgs!
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.eq(wethTraded)
    })

    it('V2, then V3', async () => {
      const v2Tokens = [DAI.address, USDC.address]
      const v3Tokens = [USDC.address, WETH.address]
      const v2AmountIn: BigNumber = expandTo18DecimalsBN(5)
      const v2AmountOutMin = 0 // USDC 数量多少无所谓，重要的是交易的最终结果
      const v3AmountOutMin = expandTo18DecimalsBN(0.0005)

      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [
        ADDRESS_THIS,
        v2AmountIn,
        v2AmountOutMin,
        v2Tokens,
        SOURCE_MSG_SENDER,
        [],
      ])
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        MSG_SENDER,
        CONTRACT_BALANCE,
        v3AmountOutMin,
        encodePathExactInput(v3Tokens),
        SOURCE_ROUTER,
        [],
      ])

      const { wethBalanceBefore, wethBalanceAfter, v3SwapEventArgs } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      const { amount1: wethTraded } = v3SwapEventArgs!
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.eq(wethTraded.mul(-1))
    })
  })

  describe('Split routes', () => {
    it('ERC20 --> ERC20 split V2 and V2 different routes, each two hop, with explicit permit transfer from', async () => {
      const route1 = [DAI.address, USDC.address, WETH.address]
      const route2 = [DAI.address, USDT.address, WETH.address]
      const v2AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v2AmountIn2: BigNumber = expandTo18DecimalsBN(30)
      const minAmountOut1 = expandTo18DecimalsBN(0.005)
      const minAmountOut2 = expandTo18DecimalsBN(0.0075)

      // 1) 将资金转入 DAI-USDC 和 DAI-USDT 交易对用于交易
      planner.addCommand(CommandType.PERMIT2_TRANSFER_FROM, [DAI.address, Pair.getAddress(DAI, USDC), v2AmountIn1])
      planner.addCommand(CommandType.PERMIT2_TRANSFER_FROM, [DAI.address, Pair.getAddress(DAI, USDT), v2AmountIn2])

      // 2) 按 route1 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [MSG_SENDER, 0, minAmountOut1, route1, SOURCE_MSG_SENDER, []])
      // 3) 按 route2 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [MSG_SENDER, 0, minAmountOut2, route2, SOURCE_MSG_SENDER, []])

      const { wethBalanceBefore, wethBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.be.gte(minAmountOut1.add(minAmountOut2))
    })

    it('ERC20 --> ERC20 split V2 and V2 different routes, each two hop, with explicit permit transfer from batch', async () => {
      const route1 = [DAI.address, USDC.address, WETH.address]
      const route2 = [DAI.address, USDT.address, WETH.address]
      const v2AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v2AmountIn2: BigNumber = expandTo18DecimalsBN(30)
      const minAmountOut1 = expandTo18DecimalsBN(0.005)
      const minAmountOut2 = expandTo18DecimalsBN(0.0075)

      const BATCH_TRANSFER = [
        {
          from: bob.address,
          to: Pair.getAddress(DAI, USDC),
          amount: v2AmountIn1,
          token: DAI.address,
        },
        {
          from: bob.address,
          to: Pair.getAddress(DAI, USDT),
          amount: v2AmountIn2,
          token: DAI.address,
        },
      ]

      // 1) 将资金转入 DAI-USDC 和 DAI-USDT 交易对用于交易
      planner.addCommand(CommandType.PERMIT2_TRANSFER_FROM_BATCH, [BATCH_TRANSFER])

      // 2) 按 route1 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [MSG_SENDER, 0, minAmountOut1, route1, SOURCE_MSG_SENDER, []])
      // 3) 按 route2 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [MSG_SENDER, 0, minAmountOut2, route2, SOURCE_MSG_SENDER, []])

      const { wethBalanceBefore, wethBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.be.gte(minAmountOut1.add(minAmountOut2))
    })

    it('ERC20 --> ERC20 split V2 and V2 different routes, each two hop, without explicit permit', async () => {
      const route1 = [DAI.address, USDC.address, WETH.address]
      const route2 = [DAI.address, USDT.address, WETH.address]
      const v2AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v2AmountIn2: BigNumber = expandTo18DecimalsBN(30)
      const minAmountOut1 = expandTo18DecimalsBN(0.005)
      const minAmountOut2 = expandTo18DecimalsBN(0.0075)

      // 1) 按 route1 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [
        MSG_SENDER,
        v2AmountIn1,
        minAmountOut1,
        route1,
        SOURCE_MSG_SENDER,
        [],
      ])
      // 2) 按 route2 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [
        MSG_SENDER,
        v2AmountIn2,
        minAmountOut2,
        route2,
        SOURCE_MSG_SENDER,
        [],
      ])

      const { wethBalanceBefore, wethBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.be.gte(minAmountOut1.add(minAmountOut2))
    })

    it('PERMIT2 batch can silently fail', async () => {
      const v2AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v2AmountIn2: BigNumber = expandTo18DecimalsBN(5)

      const BATCH_PERMIT = {
        details: [
          {
            token: DAI.address,
            amount: v2AmountIn1,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
          {
            token: WETH.address,
            amount: v2AmountIn2,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
        ],
        spender: router.address,
        sigDeadline: DEADLINE,
      }

      const sig = await getPermitBatchSignature(BATCH_PERMIT, bob, permit2)

      // 将资金转入 DAI-USDC 和 DAI-USDT 交易对用于交易
      // 不允许回滚（revert）
      planner.addCommand(CommandType.PERMIT2_PERMIT_BATCH, [BATCH_PERMIT, sig])

      // 允许回滚（revert）
      planner.addCommand(CommandType.PERMIT2_PERMIT_BATCH, [BATCH_PERMIT, sig], true)

      let nonce = (await permit2.allowance(bob.address, DAI.address, router.address)).nonce
      expect(nonce).to.eq(0)

      await executeRouter(planner, bob, router, wethContract, daiContract, usdcContract)

      nonce = (await permit2.allowance(bob.address, DAI.address, router.address)).nonce
      expect(nonce).to.eq(1)
    })

    it('ERC20 --> ERC20 split V2 and V2 different routes, different input tokens, each two hop, with batch permit', async () => {
      const route1 = [DAI.address, WETH.address, USDC.address]
      const route2 = [WETH.address, DAI.address, USDC.address]
      const v2AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v2AmountIn2: BigNumber = expandTo18DecimalsBN(5)
      const minAmountOut1 = BigNumber.from(0.005 * 10 ** 6)
      const minAmountOut2 = BigNumber.from(0.0075 * 10 ** 6)

      const BATCH_PERMIT = {
        details: [
          {
            token: DAI.address,
            amount: v2AmountIn1,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
          {
            token: WETH.address,
            amount: v2AmountIn2,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
        ],
        spender: router.address,
        sigDeadline: DEADLINE,
      }

      const sig = await getPermitBatchSignature(BATCH_PERMIT, bob, permit2)

      // 1) 将资金转入 DAI-USDC 和 DAI-USDT 交易对用于交易
      planner.addCommand(CommandType.PERMIT2_PERMIT_BATCH, [BATCH_PERMIT, sig])

      // 2) 按 route1 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [
        MSG_SENDER,
        v2AmountIn1,
        minAmountOut1,
        route1,
        SOURCE_MSG_SENDER,
        [],
      ])
      // 3) 按 route2 交易并将代币返还给 bob
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [
        MSG_SENDER,
        v2AmountIn2,
        minAmountOut2,
        route2,
        SOURCE_MSG_SENDER,
        [],
      ])

      const { usdcBalanceBefore, usdcBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(usdcBalanceAfter.sub(usdcBalanceBefore)).to.be.gte(minAmountOut1.add(minAmountOut2))
    })

    it('ERC20 --> ERC20 V3 trades with different input tokens with batch permit and batch transfer', async () => {
      const route1 = [DAI.address, WETH.address]
      const route2 = [WETH.address, USDC.address]
      const v3AmountIn1: BigNumber = expandTo18DecimalsBN(20)
      const v3AmountIn2: BigNumber = expandTo18DecimalsBN(5)
      const minAmountOut1WETH = BigNumber.from(0)
      const minAmountOut1USDC = BigNumber.from(0.005 * 10 ** 6)
      const minAmountOut2USDC = BigNumber.from(0.0075 * 10 ** 6)

      const BATCH_PERMIT = {
        details: [
          {
            token: DAI.address,
            amount: v3AmountIn1,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
          {
            token: WETH.address,
            amount: v3AmountIn2,
            expiration: 0, // expiration 为 0 表示 block.timestamp
            nonce: 0, // 这是他的第一笔交易
          },
        ],
        spender: router.address,
        sigDeadline: DEADLINE,
      }

      const BATCH_TRANSFER = [
        {
          from: bob.address,
          to: router.address,
          amount: v3AmountIn1,
          token: DAI.address,
        },
        {
          from: bob.address,
          to: router.address,
          amount: v3AmountIn2,
          token: WETH.address,
        },
      ]

      const sig = await getPermitBatchSignature(BATCH_PERMIT, bob, permit2)

      // 1) 通过 permit 允许路由器动用 dai 和 weth
      planner.addCommand(CommandType.PERMIT2_PERMIT_BATCH, [BATCH_PERMIT, sig])

      // 2) 将 dai 和 weth 转入路由器，以使用合约余额
      planner.addCommand(CommandType.PERMIT2_TRANSFER_FROM_BATCH, [BATCH_TRANSFER])

      // v3SwapExactInput(recipient, amountIn, amountOutMin, path, payer);

      // 2) 按 route1 交易并将代币返还给路由器，用于第二笔交易
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        ADDRESS_THIS,
        CONTRACT_BALANCE,
        minAmountOut1WETH,
        encodePathExactInput(route1),
        SOURCE_ROUTER,
        [],
      ])
      // 3) 按 route2 交易并将代币返还给 bob
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        MSG_SENDER,
        CONTRACT_BALANCE,
        minAmountOut1USDC.add(minAmountOut2USDC),
        encodePathExactInput(route2),
        SOURCE_ROUTER,
        [],
      ])

      const { usdcBalanceBefore, usdcBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(usdcBalanceAfter.sub(usdcBalanceBefore)).to.be.gte(minAmountOut1USDC.add(minAmountOut2USDC))
    })

    it('ERC20 --> ERC20 split V2 and V3, one hop', async () => {
      const tokens = [DAI.address, WETH.address]
      const v2AmountIn: BigNumber = expandTo18DecimalsBN(2)
      const v3AmountIn: BigNumber = expandTo18DecimalsBN(3)
      const minAmountOut = expandTo18DecimalsBN(0.0005)

      // V2 将 DAI 兑换为 USDC，并把代币发回路由器用于 v3 交易
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [ADDRESS_THIS, v2AmountIn, 0, tokens, SOURCE_MSG_SENDER, []])
      // V3 将 USDC 兑换为 WETH，兑换全部余额，接收方为 Alice
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        ADDRESS_THIS,
        v3AmountIn,
        0,
        encodePathExactInput(tokens),
        SOURCE_MSG_SENDER,
        [],
      ])
      // 汇总滑点检查
      planner.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, minAmountOut])

      const { wethBalanceBefore, wethBalanceAfter, v2SwapEventArgs, v3SwapEventArgs } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      const { amount1Out: wethOutV2 } = v2SwapEventArgs!
      let { amount1: wethOutV3 } = v3SwapEventArgs!

      // expect(daiBalanceBefore.sub(daiBalanceAfter)).to.eq(v2AmountIn.add(v3AmountIn)) // TODO: 使用 permit2 时可从 alice 的余额检查
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.eq(wethOutV2.sub(wethOutV3))
    })

    it('ETH --> ERC20 split V2 and V3, one hop', async () => {
      const tokens = [WETH.address, USDC.address]
      const v2AmountIn: BigNumber = expandTo18DecimalsBN(2)
      const v3AmountIn: BigNumber = expandTo18DecimalsBN(3)
      const value = v2AmountIn.add(v3AmountIn)

      planner.addCommand(CommandType.WRAP_ETH, [ADDRESS_THIS, value])
      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [ADDRESS_THIS, v2AmountIn, 0, tokens, SOURCE_ROUTER, []])
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        ADDRESS_THIS,
        v3AmountIn,
        0,
        encodePathExactInput(tokens),
        SOURCE_MSG_SENDER,
        [],
      ])
      // 汇总滑点检查
      planner.addCommand(CommandType.SWEEP, [USDC.address, MSG_SENDER, 0.0005 * 10 ** 6])

      const { usdcBalanceBefore, usdcBalanceAfter, v2SwapEventArgs, v3SwapEventArgs } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract,
        value
      )
      const { amount0Out: usdcOutV2 } = v2SwapEventArgs!
      let { amount0: usdcOutV3 } = v3SwapEventArgs!
      usdcOutV3 = usdcOutV3.mul(-1)
      expect(usdcBalanceAfter.sub(usdcBalanceBefore)).to.eq(usdcOutV2.add(usdcOutV3))
    })

    it('ERC20 --> ETH split V2 and V3, one hop', async () => {
      const tokens = [DAI.address, WETH.address]
      const v2AmountIn: BigNumber = expandTo18DecimalsBN(20)
      const v3AmountIn: BigNumber = expandTo18DecimalsBN(30)

      planner.addCommand(CommandType.V2_SWAP_EXACT_IN, [ADDRESS_THIS, v2AmountIn, 0, tokens, SOURCE_MSG_SENDER, []])
      planner.addCommand(CommandType.V3_SWAP_EXACT_IN, [
        ADDRESS_THIS,
        v3AmountIn,
        0,
        encodePathExactInput(tokens),
        SOURCE_MSG_SENDER,
        [],
      ])
      // 汇总滑点检查
      planner.addCommand(CommandType.UNWRAP_WETH, [MSG_SENDER, expandTo18DecimalsBN(0.0005)])

      const { ethBalanceBefore, ethBalanceAfter, gasSpent, v2SwapEventArgs, v3SwapEventArgs } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      const { amount1Out: wethOutV2 } = v2SwapEventArgs!
      let { amount1: wethOutV3 } = v3SwapEventArgs!
      wethOutV3 = wethOutV3.mul(-1)

      expect(ethBalanceAfter.sub(ethBalanceBefore)).to.eq(wethOutV2.add(wethOutV3).sub(gasSpent))
    })

    it('ERC20 --> ETH split V2 and V3, exactOut, one hop', async () => {
      const tokens = [DAI.address, WETH.address]
      const v2AmountOut: BigNumber = expandTo18DecimalsBN(0.5)
      const v3AmountOut: BigNumber = expandTo18DecimalsBN(1)
      const path = encodePathExactOutput(tokens)
      const maxAmountIn = expandTo18DecimalsBN(4000)
      const fullAmountOut = v2AmountOut.add(v3AmountOut)

      planner.addCommand(CommandType.V2_SWAP_EXACT_OUT, [
        ADDRESS_THIS,
        v2AmountOut,
        maxAmountIn,
        [DAI.address, WETH.address],
        SOURCE_MSG_SENDER,
        [],
      ])
      planner.addCommand(CommandType.V3_SWAP_EXACT_OUT, [
        ADDRESS_THIS,
        v3AmountOut,
        maxAmountIn,
        path,
        SOURCE_MSG_SENDER,
        [],
      ])
      // 汇总滑点检查
      planner.addCommand(CommandType.UNWRAP_WETH, [MSG_SENDER, fullAmountOut])

      const { ethBalanceBefore, ethBalanceAfter, gasSpent } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )

      // TODO: 用 permit2 测试 alice 发送的 DAI 不超过 maxAmountIn
      expect(ethBalanceAfter.sub(ethBalanceBefore)).to.eq(fullAmountOut.sub(gasSpent))
    })

    it('ERC20 --> ERC20 split V4 and V4 different routes, with wrap, aggregate slippage', async () => {
      // 路由 1：DAI -> USDC -> WETH
      // 路由 2：DAI -> USDC -> ETH，然后路由器将 ETH 包装为 WETH
      const route1 = [DAI_USDC.poolKey, USDC_WETH.poolKey]
      const route2 = [DAI_USDC.poolKey, ETH_USDC.poolKey]
      const v4AmountIn1 = expandTo18DecimalsBN(100)
      const v4AmountIn2 = expandTo18DecimalsBN(150)
      const aggregateMinOut = expandTo18DecimalsBN(250 / Math.floor(USD_ETH_PRICE * 1.01))

      let currencyIn = daiContract.address
      // 将第一个拆分加入 v4 planner
      v4Planner.addAction(Actions.SWAP_EXACT_IN, [
        {
          currencyIn,
          path: encodeMultihopExactInPath(route1, currencyIn),
          minHopPriceX36: [],
          amountIn: v4AmountIn1,
          amountOutMinimum: 0,
        },
      ])
      // 将第二个拆分加入 v4 planner
      v4Planner.addAction(Actions.SWAP_EXACT_IN, [
        {
          currencyIn,
          path: encodeMultihopExactInPath(route2, currencyIn),
          minHopPriceX36: [],
          amountIn: v4AmountIn2,
          amountOutMinimum: 0,
        },
      ])
      // 结算全部 DAI，不设上限
      v4Planner.addAction(Actions.SETTLE_ALL, [currencyIn, v4AmountIn1.add(v4AmountIn2)])
      // 将全部 WETH 和全部 ETH 取到路由器中
      v4Planner.addAction(Actions.TAKE, [WETH.address, ADDRESS_THIS, OPEN_DELTA])
      v4Planner.addAction(Actions.TAKE, [ETH_ADDRESS, ADDRESS_THIS, OPEN_DELTA])

      planner.addCommand(CommandType.V4_SWAP, [v4Planner.actions, v4Planner.params])
      // 将全部 ETH 包装为 WETH
      planner.addCommand(CommandType.WRAP_ETH, [ADDRESS_THIS, CONTRACT_BALANCE])
      // 现在可以将 WETH 发送给用户，并进行汇总滑点检查
      planner.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, aggregateMinOut])

      const { daiBalanceBefore, daiBalanceAfter, wethBalanceBefore, wethBalanceAfter } = await executeRouter(
        planner,
        bob,
        router,
        wethContract,
        daiContract,
        usdcContract
      )
      expect(wethBalanceAfter.sub(wethBalanceBefore)).to.be.gte(aggregateMinOut)
      expect(daiBalanceBefore.sub(daiBalanceAfter)).to.be.eq(v4AmountIn1.add(v4AmountIn2))
    })

    describe('Batch reverts', () => {
      let subplan: RoutePlanner
      const planOneTokens = [DAI.address, WETH.address]
      const planTwoTokens = [USDC.address, WETH.address]
      const planOneV2AmountIn: BigNumber = expandTo18DecimalsBN(2)
      const planOneV3AmountIn: BigNumber = expandTo18DecimalsBN(3)
      const planTwoV3AmountIn = expandTo6DecimalsBN(5)

      beforeEach(async () => {
        subplan = new RoutePlanner()
      })

      it('2 sub-plans, neither fails', async () => {
        // 第一个拆分路由子计划。DAI->WETH，V2 和 V3 上的 2 条路由。
        const planOneWethMinOut = expandTo18DecimalsBN(0.0005)

        // V2 将 DAI 兑换为 USDC，并把代币发回路由器用于 v3 交易
        subplan.addCommand(CommandType.V2_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV2AmountIn,
          0,
          planOneTokens,
          SOURCE_MSG_SENDER,
          [],
        ])
        // V3 将 USDC 兑换为 WETH，兑换全部余额，接收方为 Alice
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV3AmountIn,
          0,
          encodePathExactInput(planOneTokens),
          SOURCE_MSG_SENDER,
          [],
        ])
        // 汇总滑点检查
        subplan.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, planOneWethMinOut])

        // 将子计划加入主 planner
        planner.addSubPlan(subplan)
        subplan = new RoutePlanner()

        // 第二个拆分路由子计划。USDC->WETH，V3 上的 1 条路由
        const wethMinAmountOut2 = expandTo18DecimalsBN(0.0005)

        // 将该交易加入子计划
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          MSG_SENDER,
          planTwoV3AmountIn,
          wethMinAmountOut2,
          encodePathExactInput(planTwoTokens),
          SOURCE_MSG_SENDER,
          [],
        ])

        // 将第二个子计划加入主 planner
        planner.addSubPlan(subplan)

        const { usdcBalanceBefore, usdcBalanceAfter, daiBalanceBefore, daiBalanceAfter } = await executeRouter(
          planner,
          bob,
          router,
          wethContract,
          daiContract,
          usdcContract
        )

        expect(daiBalanceBefore.sub(daiBalanceAfter)).to.eq(planOneV2AmountIn.add(planOneV3AmountIn))
        expect(usdcBalanceBefore.sub(usdcBalanceAfter)).to.eq(planTwoV3AmountIn)
      })

      it('2 sub-plans, the first fails', async () => {
        // 第一个拆分路由子计划。DAI->WETH，V2 和 V3 上的 2 条路由。
        // FAIL: 设置很大的 weth 输出数量以导致失败
        const planOneWethMinOut = expandTo18DecimalsBN(1)

        // V2 将 DAI 兑换为 USDC，并把代币发回路由器用于 v3 交易
        subplan.addCommand(CommandType.V2_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV2AmountIn,
          0,
          planOneTokens,
          SOURCE_MSG_SENDER,
          [],
        ])
        // V3 将 USDC 兑换为 WETH，兑换全部余额，接收方为 Alice
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV3AmountIn,
          0,
          encodePathExactInput(planOneTokens),
          SOURCE_MSG_SENDER,
          [],
        ])
        // 汇总滑点检查
        subplan.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, planOneWethMinOut])

        // 将子计划加入主 planner
        planner.addSubPlan(subplan)
        subplan = new RoutePlanner()

        // 第二个拆分路由子计划。USDC->WETH，V3 上的 1 条路由
        const wethMinAmountOut2 = expandTo18DecimalsBN(0.0005)

        // 将该交易加入子计划
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          MSG_SENDER,
          planTwoV3AmountIn,
          wethMinAmountOut2,
          encodePathExactInput(planTwoTokens),
          SOURCE_MSG_SENDER,
          [],
        ])

        // 将第二个子计划加入主 planner
        planner.addSubPlan(subplan)

        const { usdcBalanceBefore, usdcBalanceAfter, daiBalanceBefore, daiBalanceAfter } = await executeRouter(
          planner,
          bob,
          router,
          wethContract,
          daiContract,
          usdcContract
        )

        // 由于 weth 清扫失败，dai 余额应保持不变
        expect(daiBalanceBefore).to.eq(daiBalanceAfter)

        // usdc 属于第二笔交易，因此余额已变化
        expect(usdcBalanceBefore.sub(usdcBalanceAfter)).to.eq(planTwoV3AmountIn)
      })

      it('2 sub-plans, both fail but the transaction succeeds', async () => {
        // 第一个拆分路由子计划。DAI->WETH，V2 和 V3 上的 2 条路由。
        // FAIL: 设置很大的输出数量以使兑换回滚（revert）
        const planOneWethMinOut = expandTo18DecimalsBN(1)

        // V2 将 DAI 兑换为 USDC，并把代币发回路由器用于 v3 交易
        subplan.addCommand(CommandType.V2_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV2AmountIn,
          0,
          planOneTokens,
          SOURCE_MSG_SENDER,
          [],
        ])
        // V3 将 USDC 兑换为 WETH，兑换全部余额，接收方为 Alice
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV3AmountIn,
          0,
          encodePathExactInput(planOneTokens),
          SOURCE_MSG_SENDER,
          [],
        ])
        // 汇总滑点检查
        subplan.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, planOneWethMinOut])

        // 将子计划加入主 planner
        planner.addSubPlan(subplan)
        subplan = new RoutePlanner()

        // 第二个拆分路由子计划。USDC->WETH，V3 上的 1 条路由
        // FAIL: 设置很大的输出数量以使兑换回滚（revert）
        const wethMinAmountOut2 = expandTo18DecimalsBN(1)

        // 将该交易加入子计划
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          MSG_SENDER,
          planTwoV3AmountIn,
          wethMinAmountOut2,
          encodePathExactInput(planTwoTokens),
          SOURCE_MSG_SENDER,
          [],
        ])

        // 将第二个子计划加入主 planner
        planner.addSubPlan(subplan)

        const { usdcBalanceBefore, usdcBalanceAfter, daiBalanceBefore, daiBalanceAfter } = await executeRouter(
          planner,
          bob,
          router,
          wethContract,
          daiContract,
          usdcContract
        )

        // 由于两笔交易都失败，dai 和 usdc 余额都未变化
        expect(daiBalanceBefore).to.eq(daiBalanceAfter)
        expect(usdcBalanceBefore).to.eq(usdcBalanceAfter)
      })

      it('2 sub-plans, second sub plan fails', async () => {
        // 第一个拆分路由子计划。DAI->WETH，V2 和 V3 上的 2 条路由。
        const planOneWethMinOut = expandTo18DecimalsBN(0.0005)

        // V2 将 DAI 兑换为 USDC，并把代币发回路由器用于 v3 交易
        subplan.addCommand(CommandType.V2_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV2AmountIn,
          0,
          planOneTokens,
          SOURCE_MSG_SENDER,
          [],
        ])
        // V3 将 USDC 兑换为 WETH，兑换全部余额，接收方为 Alice
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          ADDRESS_THIS,
          planOneV3AmountIn,
          0,
          encodePathExactInput(planOneTokens),
          SOURCE_MSG_SENDER,
          [],
        ])
        // 汇总滑点检查
        subplan.addCommand(CommandType.SWEEP, [WETH.address, MSG_SENDER, planOneWethMinOut])

        // 将子计划加入主 planner
        planner.addSubPlan(subplan)
        subplan = new RoutePlanner()

        // 第二个拆分路由子计划。USDC->WETH，V3 上的 1 条路由
        // FAIL: 设置很大的输出数量以使兑换回滚（revert）
        const wethMinAmountOut2 = expandTo18DecimalsBN(1)

        // 将该交易加入子计划
        subplan.addCommand(CommandType.V3_SWAP_EXACT_IN, [
          MSG_SENDER,
          planTwoV3AmountIn,
          wethMinAmountOut2,
          encodePathExactInput(planTwoTokens),
          SOURCE_MSG_SENDER,
          [],
        ])

        // 将第二个子计划加入主 planner
        planner.addSubPlan(subplan)

        const { usdcBalanceBefore, usdcBalanceAfter, daiBalanceBefore, daiBalanceAfter } = await executeRouter(
          planner,
          bob,
          router,
          wethContract,
          daiContract,
          usdcContract
        )

        // dai 余额已变化，因为这笔交易应当成功
        expect(daiBalanceBefore.sub(daiBalanceAfter)).to.eq(planOneV2AmountIn.add(planOneV3AmountIn))

        // usdc 未变化，因为第二笔交易应当已失败
        expect(usdcBalanceBefore).to.eq(usdcBalanceAfter)
      })
    })
  })
})
