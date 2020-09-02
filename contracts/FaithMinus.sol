// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import './CharityDapp.sol';

contract FaithMiners {
    
    CharityDapp proposal;

    uint256 private minProposalStakes = 100;        //min deposit req to submit any proposal
    function checkProposal(address _proposalAddress) public returns (bool){
        proposal = new CharityDapp();
        // uint256 numberOfTransactionsToClaimFund = proposal.proposals[_proposalAddress].fundingGoal/proposal.proposals(_proposalAddress).userStakes;
        // require(proposal.proposals(_proposalAddress).reviewPeriod > 1,"The review period should be greater than 1 day");
        // require(proposal.proposals(_proposalAddress).delegatedTimePeriod > numberOfTransactionsToClaimFund * proposal.proposals(_proposalAddress).reviewPeriod,"Not enough time is delegated to the stakes for funding in Charity Dapp");
        // require(proposal.proposals(_proposalAddress).userStakes > minProposalStakes, "The stakes are not enough for creating a proposal");
        return true;
    }
}