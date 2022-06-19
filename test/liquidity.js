const { ethers } = require('ethers')
const { Token } = require('@uniswap/sdk-core')
const { Pool, Position, nearestUsableTick } = require('@uniswap/v3-sdk')
const { abi: IUniswapV3PoolABI }  = require("@uniswap/v3-core/artifacts/contracts/interfaces/IUniswapV3Pool.sol/IUniswapV3Pool.json")
const { abi: INonfungiblePositionManagerABI } = require('@uniswap/v3-periphery/artifacts/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json')
const ERC20ABI = require('./abi.json')

require('dotenv').config()
const INFURA_URL_TESTNET = 'http://localhost:8545'
const WALLET_ADDRESS = process.env.TREASURY
const WALLET_SECRET = process.env.PRIVATE_KEY

const chainId = 31337;

let poolAddress
const positionManagerAddress = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88" // NonfungiblePositionManager

const provider = new ethers.providers.JsonRpcProvider(INFURA_URL_TESTNET)

const name0 = 'Matic'
const symbol0 = 'MATIC'
const decimals0 = 18
const address0 = process.env.WMATIC

const name1 = 'C250Gold'
const symbol1 = 'C250G'
const decimals1 = 18
const address1 = ''

let WethToken
let UniToken

const nonfungiblePositionManagerContract = new ethers.Contract(
  positionManagerAddress,
  INonfungiblePositionManagerABI,
  provider
)
let poolContract

async function getPoolData(poolContract) {
  const [tickSpacing, fee, liquidity, slot0] = await Promise.all([
    poolContract.tickSpacing(),
    poolContract.fee(),
    poolContract.liquidity(),
    poolContract.slot0(),
  ])

  return {
    tickSpacing: tickSpacing,
    fee: fee,
    liquidity: liquidity,
    sqrtPriceX96: slot0[0],
    tick: slot0[1],
  }
}


async function addLiquidity(_address1, _pool, amount0, amount1) {
  address1 = _address1
  poolAddress = _pool

  WethToken = new Token(chainId, address0, decimals0, symbol0, name0)
  UniToken = new Token(chainId, address1, decimals1, symbol1, name1)

  poolContract = new ethers.Contract(
    poolAddress,
    IUniswapV3PoolABI,
    provider
  )

  const poolData = await getPoolData(poolContract)

  const WETH_UNI_POOL = new Pool(
    WethToken,
    UniToken,
    poolData.fee,
    poolData.sqrtPriceX96.toString(),
    poolData.liquidity.toString(),
    poolData.tick
  )

  const position = new Position({
    pool: WETH_UNI_POOL,
    liquidity: ethers.utils.parseUnits(amount0.toString(), 18),
    tickLower: nearestUsableTick(poolData.tick, poolData.tickSpacing) - poolData.tickSpacing * 2,
    tickUpper: nearestUsableTick(poolData.tick, poolData.tickSpacing) + poolData.tickSpacing * 2,
  })

  const wallet = new ethers.Wallet(WALLET_SECRET)
  const connectedWallet = wallet.connect(provider)

  const approvalAmount = ethers.utils.parseUnits(amount1.toString(), 18).toString()
  const tokenContract0 = new ethers.Contract(address0, ERC20ABI, provider)
  await tokenContract0.connect(connectedWallet).approve(
    positionManagerAddress,
    approvalAmount
  )
  const tokenContract1 = new ethers.Contract(address1, ERC20ABI, provider)
  await tokenContract1.connect(connectedWallet).approve(
    positionManagerAddress,
    approvalAmount
  )

  const { amount0: amount0Desired, amount1: amount1Desired} = position.mintAmounts
  // mintAmountsWithSlippage

  params = {
    token0: address0,
    token1: address1,
    fee: poolData.fee,
    tickLower: nearestUsableTick(poolData.tick, poolData.tickSpacing) - poolData.tickSpacing * 2,
    tickUpper: nearestUsableTick(poolData.tick, poolData.tickSpacing) + poolData.tickSpacing * 2,
    amount0Desired: amount0Desired.toString(),
    amount1Desired: amount1Desired.toString(),
    amount0Min: amount0Desired.toString(),
    amount1Min: amount1Desired.toString(),
    recipient: WALLET_ADDRESS,
    deadline: Math.floor(Date.now() / 1000) + (60 * 10)
  }

  nonfungiblePositionManagerContract.connect(connectedWallet).mint(
    params,
    { gasLimit: ethers.utils.hexlify(1000000) }
  ).then((res) => {
    console.log(res)
  })
}

module.exports = {
  addLiquidity
}
