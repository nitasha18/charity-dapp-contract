pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import './KYC.sol';
import './CharityInterface.sol';
import './safemath.sol';
import './TimeAllyManager.sol';
import {FaithMiners} from './FaithMinus.sol';

contract CharityDapp is CharityInterface{
    using SafeMath for uint256;

    address public curator;
    uint256 public charityPoolDonations;
    
    constructor() public payable 
    {
        curator = msg.sender;   
    }
    
    receive() external payable 
    { 
        charityPoolDonations += msg.value;              //if the contract is called from another contract with amount it will stored in the pool
    }
    
    struct Proposal {
        
        //basic information about the funding
        address payable recipient;                      //addr where amount will go if proposal is approved 
        uint256 fundingGoal;                            //total amount for raisingthe fund
        uint256 raisedFunds;                             //funds which have been raised for the proposal
        uint256 claimedFunds;                           //funds which are claimed by the user
        
        string description;                             //description of the proposal
        
        uint256 endTime;                                //endtime for funding completion
        uint256 fundRaisingDeadline;                    //open for plateform users to donate --> period
        
        //for checking the availablebility of funding proposal
        bool fullExtraction;                            //whether want to have whole fund out or just as much as raised
        bool openForFunding;                            //active or not for funding
        
        bool proposalApproved;
        
        //staking details of the user from timeAlly
        uint256 userStakes;                             //stakes reserved for fund raising
        uint256 delegatedTimePeriod;                    //time period upto which this delegated amount has been staked
        
        //For claming the funds
        uint256 reviewPeriod;                           //time period after how much the person will give the proof of work done
        uint256 currentReviewCount;                     //number of review period the person has submitted
        mapping (uint256 => string) reviewedProof;      //proof stored with [amount]->work done (string) :for testing
    } 
    
    modifier onlyOwner() {
        require(msg.sender == curator);
        _;
    }
    
    //temprorary variables for testing purpose
    uint256 currentTime = 0;
    
    // Proposal[] public proposals;
    mapping (address => Proposal) public proposals;
    
    event ProposalAdded(address recipient, uint256 amount, string description);
    event Donated(address proposalAddress, address donorAddress, uint256 amount);
    event ProposalEnded(address recipient,uint256 amount, string description);
    
    
    function newProposal(uint256 _fundingGoal, string memory _description, uint256 _endTime, uint256 _fundRaisingDeadline, bool _fullExtraction, uint256 _delegatedPeriod, uint256 _reviewPeriod) public
    {
        ITimeAllyManager tm;
        
        require(_endTime >= (_delegatedPeriod)  , "Deadline for ending the fund is not sufficient since it should also include the claiming period");
        require(tm.isStakingContractValid(msg.sender),"The beneficiery should have stakeing timeAlly contract");
        
        Proposal storage p = proposals[msg.sender];
        
        p.recipient = msg.sender;
        p.fundingGoal = _fundingGoal;
        p.raisedFunds = 0;
        p.claimedFunds = 0;
        
        p.description = _description;
        
        p.endTime = _endTime  ;
        p.fundRaisingDeadline = _fundRaisingDeadline;
        
        p.fullExtraction = _fullExtraction;
        p.openForFunding = true;
        p.proposalApproved=false;
        
        p.userStakes = tm.getTotalActiveStaking(_delegatedPeriod);      //erc173 integration TODO
        p.delegatedTimePeriod = _delegatedPeriod;
        p.reviewPeriod = _reviewPeriod;
        p.currentReviewCount = 0;

        emit ProposalAdded(msg.sender,_fundingGoal,_description);
        approveProposal(p.recipient);
    }
    
    function approveProposal(address _proposalAddress) internal {
        FaithMiners fm;
        Proposal storage p = proposals[_proposalAddress];
        p.proposalApproved = fm.checkProposal(_proposalAddress);
    }
    
    function donate(address payable _proposalAddress, uint256 _donateAmount) public onlyDonor returns (bool success)
    {
        Proposal storage p = proposals[_proposalAddress];
        // require(d.isRegistered,"The donor is not registered");
        // require(d.donations > 0,"The donor doesn't have sufficient amount in their wallet");
        // require(_donateAmount <= d.donations, "The donor dont have suffiecient tokens to donate");
        
        require(currentTime <= (p.fundRaisingDeadline)  ,"For donating the timelimit has exceeded");
        require(currentTime <= (p.endTime)  ,"The proposal has reached its deadline");
        
        require(p.openForFunding,"The proposal funding period has been closed");
        
        require(_donateAmount <= (p.fundingGoal-p.raisedFunds), "The proposal doesn't need that much of donations");
        
        
        p.raisedFunds += _donateAmount;         //amount would be added to the proposal funds
        if(p.fundRaisingDeadline <= currentTime || p.raisedFunds == p.fundingGoal)
        {
            p.openForFunding = false;
        }
        emit Donated(_proposalAddress, msg.sender, _donateAmount);
        return true;
    }
    
    
    function votingPanel(address _proposalAddress) external onlyFaithminersAndDaogoverners {
        Proposal storage p = proposals[_proposalAddress];
        
        require(p.fullExtraction==true,"This will only applicable for those proposal who wish to raise full funding goal"); 
        require(charityPoolDonations > (p.fundingGoal-p.raisedFunds), "The pool should have enough tokens for the proposal");
        
        require(p.proposalApproved,"The proposal is yet to get the approvals");
        require(!p.openForFunding,"The proposal funding period should be closed");
        
        p.raisedFunds = p.fundingGoal;
        charityPoolDonations -= (p.fundingGoal-p.raisedFunds);
        p.fundingGoal = 0;
        p.openForFunding = false;
        emit Donated(_proposalAddress, curator, (p.fundingGoal - p.raisedFunds));
    }
    
    function claimFunds(address _proposalAddress, string memory _proof) public payable returns (bool) {
        
        Proposal storage p = proposals[_proposalAddress];
        
        require(msg.sender == p.recipient,"Only the recipient is authorised to claimed the funds");
        require(!p.openForFunding, "The proposal is still up and is going on");
        
        require(p.claimedFunds < p.fundingGoal, "The funds have been already claimed");
        require(p.proposalApproved,"The proposal should be approved");
        
        
        uint256 numberOfTransactionsToClaimFund = p.fundingGoal/p.userStakes;
        require(p.currentReviewCount <= numberOfTransactionsToClaimFund, "The review is yet to add");
        
        p.reviewedProof[p.currentReviewCount++] = _proof;
        p.recipient.transfer(p.userStakes); 
        p.claimedFunds += p.userStakes;
        if(p.currentReviewCount == numberOfTransactionsToClaimFund || p.claimedFunds == p.raisedFunds)
        {
            emit ProposalEnded(p.recipient,p.claimedFunds,p.description);
        }
        return true;
    }
  
    // function getProposal(address _proposalAddress) public view returns (uint256, uint256, uint256, string memory,uint256,uint256,bool,bool,bool, uint256,uint256, uint256,uint256){
    //     return (proposals[_proposalAddress].fundingGoal,
    //             proposals[_proposalAddress].raisedFunds,
    //             proposals[_proposalAddress].claimedFunds,
    //             proposals[_proposalAddress].description,
    //             proposals[_proposalAddress].endTime,
    //             proposals[_proposalAddress].fundRaisingDeadline,
    //             proposals[_proposalAddress].fullExtraction,
    //             proposals[_proposalAddress].openForFunding,
    //             proposals[_proposalAddress].proposalApproved,
    //             proposals[_proposalAddress].userStakes,
    //             proposals[_proposalAddress].delegatedTimePeriod,
    //             proposals[_proposalAddress].reviewPeriod,
    //             proposals[_proposalAddress].currentReviewCount);
    // }
}