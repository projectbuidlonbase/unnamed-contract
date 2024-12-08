// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrowdFunding} from "../src/CrowdFunding.sol";

contract CrowdFundingTest is Test {
    CrowdFunding public crowdFunding;
    address public owner;
    address public creator;
    address public donor;

    event CampaignCreated(
        uint256 indexed id,
        address indexed creator,
        string title,
        uint256 goal,
        uint256 deadline
    );

    event DonationMade(
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount
    );

    event FundsClaimed(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );

    function setUp() public {
        owner = makeAddr("owner");
        creator = makeAddr("creator");
        donor = makeAddr("donor");
        
        vm.prank(owner);
        crowdFunding = new CrowdFunding();
        
        // Fund donor with some ETH
        vm.deal(donor, 100 ether);
    }

    function test_CreateCampaign() public {
        vm.prank(creator);
        
        vm.expectEmit(true, true, false, true);
        emit CampaignCreated(1, creator, "Test Campaign", 10 ether, block.timestamp + 30 days);
        
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        assertEq(campaignId, 1);

        (
            uint256 id,
            address campaignCreator,
            string memory title,
            string memory description,
            uint256 goal,
            uint256 raised,
            uint256 deadline,
            bool claimed
        ) = crowdFunding.getCampaign(campaignId);

        assertEq(id, 1);
        assertEq(campaignCreator, creator);
        assertEq(title, "Test Campaign");
        assertEq(description, "Test Description");
        assertEq(goal, 10 ether);
        assertEq(raised, 0);
        assertEq(deadline, block.timestamp + 30 days);
        assertEq(claimed, false);
    }

    function test_DonateToValidCampaign() public {
        // First create a campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        uint256 donationAmount = 1 ether;
        
        vm.prank(donor);
        vm.expectEmit(true, true, false, true);
        emit DonationMade(campaignId, donor, donationAmount);
        
        crowdFunding.donate{value: donationAmount}(campaignId);

        assertEq(crowdFunding.getDonation(campaignId, donor), donationAmount);
        
        (,,,,, uint256 raised,,) = crowdFunding.getCampaign(campaignId);
        assertEq(raised, donationAmount);
    }

    function test_ClaimFunds() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        // Make donation
        vm.prank(donor);
        crowdFunding.donate{value: 10 ether}(campaignId);

        // Fast forward past deadline
        vm.warp(block.timestamp + 31 days);

        uint256 platformFee = (10 ether * 5) / 100; // 5% of 10 ether
        uint256 creatorAmount = 10 ether - platformFee;

        uint256 initialOwnerBalance = owner.balance;
        uint256 initialCreatorBalance = creator.balance;

        vm.prank(creator);
        vm.expectEmit(true, true, false, true);
        emit FundsClaimed(campaignId, creator, creatorAmount);
        
        crowdFunding.claimFunds(campaignId);

        assertEq(owner.balance, initialOwnerBalance + platformFee);
        assertEq(creator.balance, initialCreatorBalance + creatorAmount);
    }

    function testFail_CreateCampaignWithZeroGoal() public {
        vm.prank(creator);
        crowdFunding.createCampaign("Test Campaign", "Test Description", 0, 30);
    }

    function testFail_CreateCampaignWithInvalidDuration() public {
        vm.prank(creator);
        crowdFunding.createCampaign("Test Campaign", "Test Description", 1 ether, 366);
    }

    function testFail_DonateToNonExistentCampaign() public {
        vm.prank(donor);
        crowdFunding.donate{value: 1 ether}(999);
    }

    function testFail_DonateToExpiredCampaign() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        // Fast forward past deadline
        vm.warp(block.timestamp + 31 days);

        vm.prank(donor);
        crowdFunding.donate{value: 1 ether}(campaignId);
    }

    function testFail_ClaimFundsBeforeDeadline() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        vm.prank(donor);
        crowdFunding.donate{value: 1 ether}(campaignId);

        vm.prank(creator);
        crowdFunding.claimFunds(campaignId);
    }

    function testFail_ClaimFundsTwice() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        vm.prank(donor);
        crowdFunding.donate{value: 1 ether}(campaignId);

        vm.warp(block.timestamp + 31 days);

        vm.prank(creator);
        crowdFunding.claimFunds(campaignId);

        vm.prank(creator);
        crowdFunding.claimFunds(campaignId);
    }

    function testFail_NonCreatorClaimFunds() public {
        // Create campaign
        vm.prank(creator);
        uint256 campaignId = crowdFunding.createCampaign(
            "Test Campaign",
            "Test Description",
            10 ether,
            30
        );

        vm.prank(donor);
        crowdFunding.donate{value: 1 ether}(campaignId);

        vm.warp(block.timestamp + 31 days);

        vm.prank(donor);
        crowdFunding.claimFunds(campaignId);
    }
}
