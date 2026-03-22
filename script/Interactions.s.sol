//SPDX-License-Identifier:MIT
pragma solidity 0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {HelperConfig,CodeConstants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{
    function createSubscriptionUsingConfig()public{
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account =helperConfig.getConfig().account;
        (uint256 subId,)=createSubscription(vrfCoordinator,account);
    }

    function createSubscription(address vrfCoordinator,address account)public returns(uint256, address){
        console.log("Creating subscription on chain Id: ",block.chainid);
        vm.startBroadcast(account);
        uint256 subId=VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription id is ",subId);
        console.log("Please, update ur subscription Id in ur HelperConfig.s.sol");
        return (subId,vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}
contract FundSubscription is Script,CodeConstants{
    uint256 public constant FUND_AMOUNT = 0.05 ether;//0.05LINK

    function FundSubscriptionUsingConfig()public{
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken= helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator,subscriptionId,linkToken,account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken, address account)public{
        console.log("Funding subscription: ",subscriptionId);
        console.log("Using VRFCoordinator: ",vrfCoordinator);
        console.log("On chain id : ",block.chainid);

        if(block.chainid==LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT*10000);
            vm.stopBroadcast();
        }else{
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run()public{
        FundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{
    function addConsumerUsingConfig(address mostRecentrlyDeployed)public{
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId=helperConfig.getConfig().subscriptionId;
        address vrfCoordinator=helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentrlyDeployed,vrfCoordinator,subId,account);
    }
    function addConsumer(address contractToAddToVrf,address vrfCoordinator,uint256 subId,address account)public{
        console.log("Adding consumer to contract ", contractToAddToVrf);
        console.log("Adding consumer to VRF Coordinator ", vrfCoordinator);
        console.log("On chain id ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }
    function run()external{
        address mostRecentlyDeployed=DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}