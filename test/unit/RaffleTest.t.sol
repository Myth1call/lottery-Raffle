//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig,CodeConstants} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";


contract RaffleTest is Test,CodeConstants{
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER= makeAddr("player");

    uint256 public constant STARTING_PLAYER_BALANCE=10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external{
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig)=deployer.DeployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee=config.entranceFee;
        interval=config.interval;
        vrfCoordinator=config.vrfCoordinator;
        gasLane=config.gasLane;
        callbackGasLimit=config.callbackGasLimit;
        subscriptionId=config.subscriptionId;
        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);
    }
    function testRaffleInitialiezesInOpenState()public view{
        assert(raffle.getRaffleState()==Raffle.RaffleState.OPEN);
    }

    //Enter raffle
    function testRaffleRevertsWhenYouDontPayEnough()public{
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }
    function testRaffleRecordsPlayersWhenTheyEnter()public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        address playerRecorded=raffle.getPlayer(0);
        assert(playerRecorded==PLAYER);
    }
    function testEnteringRaffleEmitEvent()public{
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(PLAYER);
        // emit RaffleEntered(address(0));
        raffle.enterRaffle{value:entranceFee}();
    }
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating()public{
        //Arange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");
        //Act
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        //Assert
    }
    // CHECK UPKEEP

    function testCheckUpKeepReturnsFalseIfItHasNoBalance()public{
        //
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);

        (bool upkeepNeeded,)=raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen()public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,)=raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed()public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval);
        vm.roll(block.number);

        (bool upkeepNeeded,)=raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }
    // function testCheckUpkeepReturnsTrueParametersAreGood()public{
        
    // }

    //perform Upkeep
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue()public{
        //arange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        //act
        raffle.performUpkeep("");
        //assert"
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse()public{
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        uint256 expectedBalance = address(raffle).balance;
        uint256 expectedPlayers = 1;
        Raffle.RaffleState expectedState = raffle.getRaffleState();
        //act
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle_UpkeepNotNeeded.selector, expectedBalance, expectedPlayers, expectedState
            )
        );
        raffle.performUpkeep("");
        //assert
    }
    modifier raffleEntered(){
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp+interval+1);
        vm.roll(block.number+1);
        _;
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()public raffleEntered{
        //arange
        
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId=entries[1].topics[1];
        //Assert
        Raffle.RaffleState raffleState=raffle.getRaffleState();
        assert(uint256(requestId)>0);
        assert(uint256(raffleState)==1);
    }

    //FULFILLRANDOMWORDS
    modifier skipFork(){
        if(block.chainid!=LOCAL_CHAIN_ID){
            return;
        }
        _;
    }
    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 requestId) public raffleEntered skipFork{
        //arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
        //act
        //assert
    }
    function testFulFillRanndomWordsPicksAWinnerResetsAndSendsMoney()public raffleEntered skipFork{
        //Arrande
        uint256 additionalEntrants = 3; //total 4
        uint256 startingIndex=1;
        address expectedWinner=address(1);

        for(uint256 i=startingIndex;i<startingIndex+additionalEntrants;i++){
            address newPlayer=address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value:entranceFee}();
        }
        uint256 startingTimeStamp=raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        //ACT
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId=entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));
        //ASSERT
        address recentWinner = raffle.getRecentWinner();
       Raffle.RaffleState raffleState = raffle.getRaffleState();
       uint256 winnerBalance = recentWinner.balance;
       uint256 endingTimeStamp = raffle.getLastTimeStamp();
       uint256 prize = entranceFee*(additionalEntrants+1);

       assert(recentWinner == expectedWinner);
       assert(uint256(raffleState)==0);
       assert(winnerBalance == winnerStartingBalance+prize);
       assert(endingTimeStamp>startingTimeStamp);
    }

}