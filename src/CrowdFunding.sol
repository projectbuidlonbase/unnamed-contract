// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CrowdFunding is ReentrancyGuard, Ownable {
    struct Campaign {
        uint256 id;
        address payable creator;
        string title;
        string description;
        uint256 goal;
        uint256 raised;
        uint256 deadline;
        bool claimed;
        bool exists;
    }

    uint256 private campaignCount;
    uint256 private constant PLATFORM_FEE = 5; // 5% platform fee
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public donations;
    
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

    constructor() Ownable(msg.sender) {}

    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _durationInDays
    ) external returns (uint256) {
        require(_goal > 0, "Goal must be greater than 0");
        require(_durationInDays > 0 && _durationInDays <= 365, "Invalid duration");

        campaignCount++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);

        campaigns[campaignCount] = Campaign({
            id: campaignCount,
            creator: payable(msg.sender),
            title: _title,
            description: _description,
            goal: _goal,
            raised: 0,
            deadline: deadline,
            claimed: false,
            exists: true
        });

        emit CampaignCreated(
            campaignCount,
            msg.sender,
            _title,
            _goal,
            deadline
        );

        return campaignCount;
    }

    function donate(uint256 _campaignId) external payable nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.exists, "Campaign does not exist");
        require(block.timestamp < campaign.deadline, "Campaign has ended");
        require(msg.value > 0, "Donation must be greater than 0");

        campaign.raised += msg.value;
        donations[_campaignId][msg.sender] += msg.value;

        emit DonationMade(_campaignId, msg.sender, msg.value);
    }

    function claimFunds(uint256 _campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[_campaignId];
        require(campaign.exists, "Campaign does not exist");
        require(msg.sender == campaign.creator, "Only creator can claim");
        require(!campaign.claimed, "Funds already claimed");
        require(
            block.timestamp >= campaign.deadline,
            "Campaign has not ended yet"
        );

        campaign.claimed = true;
        uint256 platformFeeAmount = (campaign.raised * PLATFORM_FEE) / 100;
        uint256 creatorAmount = campaign.raised - platformFeeAmount;

        (bool platformFeeSuccess, ) = owner().call{value: platformFeeAmount}("");
        require(platformFeeSuccess, "Platform fee transfer failed");

        (bool creatorSuccess, ) = campaign.creator.call{value: creatorAmount}("");
        require(creatorSuccess, "Creator transfer failed");

        emit FundsClaimed(_campaignId, campaign.creator, creatorAmount);
    }

    function getCampaign(uint256 _campaignId) external view returns (
        uint256 id,
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool claimed
    ) {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.exists, "Campaign does not exist");
        
        return (
            campaign.id,
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.goal,
            campaign.raised,
            campaign.deadline,
            campaign.claimed
        );
    }

    function getDonation(uint256 _campaignId, address _donor) external view returns (uint256) {
        return donations[_campaignId][_donor];
    }
}
