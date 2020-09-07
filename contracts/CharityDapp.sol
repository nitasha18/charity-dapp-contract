pragma solidity 0.7.0;
pragma experimental ABIEncoderV2;
import './KYC.sol';
import './CharityInterface.sol';
import './safemath.sol';
import './TimeAllyManager.sol';
import {FaithMiners} from './FaithMinus.sol';

contract CharityDapp is CharityInterface{
    using SafeMath for uint256;

    uint256 public charityPoolDonations;

    
    receive() external payable 
    { 
        charityPoolDonations += msg.value;              //if the contract is called from another contract with amount it will stored in the pool
    }
    
    struct Organisation {
        //about the Organisation/person who have register
        address payable recipient;                      //address where amount would get transfered
        string description;                             //brief about Organisation
    }
    
    struct Campaign {
        //about the proposal input by the user
        string aboutProposal;                           //description of the proposal
        bool fullExtraction;                            //whether want to have whole fund out or just as much as raised
        uint256 fundRaisingDeadline;                    //time till the fund will be open for donating
        uint256 endTime;                                //endtime for funding completion
        uint256 campaignStakes;                             //stakes reserved for fund raising
    }
    
    struct CampaignStatus {
        
        uint256 fundingGoal;                            //total amount for raisingthe fund
        uint256 raisedFunds;                             //funds which have been raised for the proposal
        uint256 claimedFunds;                           //funds which are claimed by the user
        
        //for checking the availability of funding proposal
        bool openForFunding;                            //active or not for funding
        bool proposalApproved;                          //approved by faithminus
    } 
    
    
    uint256 currentTime = 0;                            //temprorary variables for testing purpose 
    
    // mapping of all structs
    mapping (address => Organisation) public organisations;
    mapping (address => Campaign) public campaigns;
    mapping (address => CampaignStatus) public campaignStats;
    
    event ProposalAdded(address recipient, uint256 amount, string description);
    event ProposalAproved(address recipient, uint256 amount, string description);
    event Donated(address proposalAddress, address donorAddress, uint256 amount);
    event ProposalEnded(address recipient,uint256 amount, string description);
    
    function newOrganisation(string memory _description) public {
        
        Organisation storage org = organisations[msg.sender];
        org.recipient = msg.sender;
        org.description = _description;
    }
    
    function newCampaign(string memory _aboutProposal, uint256 _fundingGoal, bool _fullExtraction, uint256 _fundRaisingDeadline, uint256 _endTime) public {
        
        ITimeAllyManager tm;
        require(tm.isStakingContractValid(msg.sender),"The beneficiery should have stakeing timeAlly contract");
        Campaign storage cam = campaigns[msg.sender];
        cam.aboutProposal = _aboutProposal;              
        setCampaignStatus(_fundingGoal);
        cam.fullExtraction = _fullExtraction;                       
        cam.fundRaisingDeadline = _fundRaisingDeadline;   
        cam.endTime = _endTime;
        cam.campaignStakes = tm.getTotalActiveStaking(_endTime);  
        
        emit ProposalAdded(msg.sender,_fundingGoal,_aboutProposal);
    }
    
    function setCampaignStatus(uint _fundingGoal) public
    {
        CampaignStatus storage cs = campaignStats[msg.sender];
                             
        cs.fundingGoal = _fundingGoal;        
        cs.raisedFunds = 0;
        cs.claimedFunds = 0;
        cs.openForFunding = true;
        cs.proposalApproved=false;
        
        approveProposal(msg.sender);
    }
    
    function approveProposal(address _proposalAddress) internal {
        FaithMiners fm;
        CampaignStatus storage cs = campaignStats[_proposalAddress];
        cs.proposalApproved = fm.checkProposal(_proposalAddress);
        emit ProposalAproved(_proposalAddress,cs.fundingGoal,campaigns[_proposalAddress].aboutProposal);
    }
    
    function donate(address payable _proposalAddress, uint256 _donateAmount) public onlyDonor returns (bool success)
    {
        CampaignStatus storage cs = campaignStats[msg.sender];
        
        require(cs.openForFunding,"The proposal funding period has been closed");
        require(_donateAmount <= (cs.fundingGoal-cs.raisedFunds), "The proposal doesn't need that much of donations");
        
        cs.raisedFunds += _donateAmount;         //amount would be added to the proposal funds
        if(cs.raisedFunds == cs.fundingGoal ||campaigns[_proposalAddress].fundRaisingDeadline <= currentTime)
        {
            cs.openForFunding = false;
        }
        emit Donated(_proposalAddress, msg.sender, _donateAmount);
        return true;
    }
    
    function votingPanel(address _proposalAddress) external onlyFaithminersAndDaogoverners 
    {
        Campaign storage cam = campaigns[_proposalAddress];
        CampaignStatus storage cs = campaignStats[_proposalAddress];
        
        require(cam.fullExtraction==true,"This will only applicable for those proposal who wish to raise full funding goal"); 
        require(charityPoolDonations > (cs.fundingGoal-cs.raisedFunds), "The pool should have enough tokens for the proposal");
        
        require(cs.proposalApproved,"The proposal is yet to get the approvals");
        require(!cs.openForFunding,"The proposal funding period should be closed");
        
        cs.raisedFunds = cs.fundingGoal;
        charityPoolDonations -= (cs.fundingGoal-cs.raisedFunds);
        cs.fundingGoal = 0;
        cs.openForFunding = false;
        emit Donated(_proposalAddress, msg.sender , (cs.fundingGoal - cs.raisedFunds));
    }
    
    function claimFunds() public payable returns (bool) {
        
        Organisation storage org = organisations[msg.sender];
        Campaign storage cam = campaigns[msg.sender];
        CampaignStatus storage cs = campaignStats[msg.sender];
        
        require(msg.sender == org.recipient,"Only the recipient is authorised to claimed the funds");
        require(cs.proposalApproved,"The proposal should be approved");
        require(!cs.openForFunding, "The proposal is still up and is going on");
        require(cs.claimedFunds < cs.fundingGoal, "The funds have been already claimed");
        
        org.recipient.transfer(cam.campaignStakes); 
        cs.claimedFunds += cam.campaignStakes;
        if(cs.claimedFunds == cs.raisedFunds)
        {
            emit ProposalEnded(org.recipient,cs.claimedFunds,cam.aboutProposal);
        }
        return true;
    }
  
    function getOrganisation(address _proposalAddress) public view returns (string memory){
        Organisation memory org = organisations[_proposalAddress];
        return (org.description);
    }
    
    function getCampaign(address _proposalAddress) public view returns (string memory, bool, uint256, uint256, uint256){
        Campaign memory cam = campaigns[msg.sender];
        return (cam.aboutProposal,cam.fullExtraction,cam.fundRaisingDeadline, cam.endTime,cam.campaignStakes);
    }
    
    function getCampaignStatus(address _proposalAddress) public view returns (uint256, uint256, uint256, bool, bool){
        CampaignStatus memory cs = campaignStats[msg.sender];
        return (cs.fundingGoal,cs.raisedFunds,cs.claimedFunds,cs.openForFunding,cs.proposalApproved);
    }
}