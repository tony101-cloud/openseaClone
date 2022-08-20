// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./PriceConverter.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// we can perhaps use the Roles instead so we can claim our royalty by ourselves
// without waiting for them to claim first then do the split
// of course this will need to do some rework.

error Event_PurchaseDatePassed();
error Event_PurchaseDateNotStarted();
error Event_NotEnoughCryptoSent();

contract Event is Ownable {
    using PriceConverter for uint256;

    enum EventState {
        OPEN,
        ONGOING,
        END
    }

    uint256 private s_eventDate;
    uint256 private s_purchaseStartDate;
    uint256 private s_purchaseEndDate;

    uint256 private s_ticketPurchased; // on mint, increase this number
    uint256 private s_ticketPrice;
    EventState private s_eventState; // not sure what this is for, saw it on docs

    address payable private immutable i_eventCreator;
    address payable private immutable i_royalty; // our wallet for service charge
    string private s_eventName;
    // details can get long, I think it's better to store somewhere else or contract will be expensive
    string private s_eventDetails;

    AggregatorV3Interface private s_priceFeed;

    event TicketPurchase(address indexed winner, address indexed nft); // not sure about this, need revision

    constructor(
        uint256 eventDate,
        uint256 purchaseStartDate,
        uint256 purchaseEndDate,
        uint256 ticketPrice,
        address payable eventCreator,
        address payable royalty,
        address priceFeedAddress,
        string memory eventName,
        string memory eventDetails
    ) {
        s_eventDate = eventDate;
        s_purchaseStartDate = purchaseStartDate;
        s_purchaseEndDate = purchaseEndDate;
        s_ticketPrice = ticketPrice; // remember this has to be *1e18 to get the correct digit
        s_ticketPurchased = 0; // we can either use constructor to designate from event creator contract or hard code here
        s_eventState = EventState.OPEN;
        i_eventCreator = eventCreator;
        i_royalty = royalty; // we can either use constructor to designate from event creator contract or hard code here
        s_priceFeed = AggregatorV3Interface(priceFeedAddress);
        s_eventName = eventName;
        s_eventDetails = eventDetails;
    }

    function purchaseTicket() public payable {
        if (msg.value.getConversionRate(s_priceFeed) < s_ticketPrice) {
            revert Event_NotEnoughCryptoSent();
        }
        // warning due to possible time manipulation of few second by miners, you guys can decide if you want to change it
        if (block.timestamp > s_purchaseEndDate) {
            revert Event_PurchaseDatePassed();
        }
        if (block.timestamp < s_purchaseStartDate) {
            revert Event_PurchaseDateNotStarted();
        }
        // nft minting
        //.....

        s_ticketPurchased++;
        emit TicketPurchase(
            msg.sender,
            msg.sender /* mint address? placeholder msg.sender */
        );
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        uint256 royalty_fee = balance * 100; // 1%

        (bool callSuccessRoyalty, ) = i_royalty.call{value: royalty_fee}("");
        require(callSuccessRoyalty, "callfailed");
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }(""); // contract has to pay gas fees also? so we take royalty first then leftover is theirs
        require(callSuccess, "callfailed");
    }

    // update functions
    function updateEventDate(uint256 newDate) private onlyOwner {
        s_eventDate = newDate;
    }

    function updatePurchaseStartDate(uint256 newStartDate) private onlyOwner {
        s_purchaseStartDate = newStartDate;
    }

    function updatePurchaseEndDate(uint256 newEndDate) private onlyOwner {
        s_purchaseEndDate = newEndDate;
    }

    function updateTicketPrice(uint256 newTicketPrice) private onlyOwner {
        s_ticketPrice = newTicketPrice;
    }

    function updateEventName(string memory newEventName) private onlyOwner {
        s_eventName = newEventName;
    }

    function updateEventDetails(string memory newEventDetails)
        private
        onlyOwner
    {
        s_eventDetails = newEventDetails;
    }

    // view / pure functions
    function getEventDate() public view returns (uint256) {
        return s_eventDate;
    }

    function gePurchaseStartDate() public view returns (uint256) {
        return s_purchaseStartDate;
    }

    function getPurchaseEndDate() public view returns (uint256) {
        return s_purchaseEndDate;
    }

    function getTicketPurchase() public view returns (uint256) {
        return s_ticketPurchased;
    }

    function getTicketPrice() public view returns (uint256) {
        return s_ticketPrice;
    }

    function getEventState() public view returns (EventState) {
        return s_eventState;
    }

    // not sure if we need the view function for eventcreator and royalty
    function getEventCreator() public view returns (address) {
        return i_eventCreator;
    }

    function getRoyalty() public view returns (address) {
        return i_royalty;
    }

    function getEventName() public view returns (string memory) {
        return s_eventName;
    }

    function getEventDetails() public view returns (string memory) {
        return s_eventDetails;
    }

    function getPriceFeed() public view returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
