// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test} from "@forge-std/Test.sol";

import {Core} from "@src/core/Core.sol";
import {MockERC20} from "@test/mock/MockERC20.sol";
import {Addresses} from "@test/proposals/Addresses.sol";
import {SimplePSM} from "@src/loan/SimplePSM.sol";
import {GuildToken} from "@src/tokens/GuildToken.sol";
import {CreditToken} from "@src/tokens/CreditToken.sol";
import {LendingTerm} from "@src/loan/LendingTerm.sol";
import {GuildGovernor} from "@src/governance/GuildGovernor.sol";
import {AuctionHouse} from "@src/loan/AuctionHouse.sol";
import {ProfitManager} from "@src/governance/ProfitManager.sol";
import {TestProposals} from "@test/proposals/TestProposals.sol";
import {ERC20MultiVotes} from "@src/tokens/ERC20MultiVotes.sol";
import {GuildVetoGovernor} from "@src/governance/GuildVetoGovernor.sol";
import {RateLimitedMinter} from "@src/rate-limits/RateLimitedMinter.sol";
import {PostProposalCheck} from "@test/integration/PostProposalCheck.sol";
import {SurplusGuildMinter} from "@src/loan/SurplusGuildMinter.sol";
import {LendingTermOnboarding} from "@src/governance/LendingTermOnboarding.sol";
import {LendingTermOffboarding} from "@src/governance/LendingTermOffboarding.sol";
import {GuildTimelockController} from "@src/governance/GuildTimelockController.sol";

contract PostProposalCheckFixture is PostProposalCheck {
    /// Users
    address public userOne = address(0x1111);
    address public userTwo = address(0x2222);
    address public userThree = address(0x3333);

    /// Core
    Core public core;

    /// Lending
    LendingTerm public term;
    LendingTermOnboarding public onboarder;
    LendingTermOffboarding public offboarder;

    ERC20 public collateralToken;

    AuctionHouse public auctionHouse;

    ProfitManager public profitManager;

    SimplePSM public psm;

    /// Tokens
    GuildToken public guild;
    CreditToken public credit;
    ERC20 public usdc;
    ERC20 public sdai;

    /// Governor
    GuildGovernor public governor;
    GuildVetoGovernor public vetoGuildGovernor;
    GuildVetoGovernor public vetoCreditGovernor;
    GuildTimelockController public timelock;

    /// Minting
    RateLimitedMinter public rateLimitedCreditMinter;
    RateLimitedMinter public rateLimitedGuildMinter;
    SurplusGuildMinter public surplusGuildMinter;

    function setUp() public virtual override {
        super.setUp();

        /// --------------------------------------- ///
        /// ------------ address setup ------------ ///
        /// --------------------------------------- ///

        /// core
        core = Core(addresses.mainnet("CORE"));

        usdc = ERC20(addresses.mainnet("ERC20_USDC"));
        sdai = ERC20(addresses.mainnet("ERC20_SDAI"));
        guild = GuildToken(addresses.mainnet("ERC20_GUILD"));
        credit = CreditToken(addresses.mainnet("ERC20_GUSDC"));

        /// rate limited minters
        rateLimitedCreditMinter = RateLimitedMinter(
            addresses.mainnet("RATE_LIMITED_CREDIT_MINTER")
        );
        rateLimitedGuildMinter = RateLimitedMinter(
            addresses.mainnet("RATE_LIMITED_GUILD_MINTER")
        );
        surplusGuildMinter = SurplusGuildMinter(
            addresses.mainnet("SURPLUS_GUILD_MINTER")
        );

        profitManager = ProfitManager(addresses.mainnet("PROFIT_MANAGER"));
        auctionHouse = AuctionHouse(addresses.mainnet("AUCTION_HOUSE"));
        psm = SimplePSM(addresses.mainnet("PSM_USDC"));

        governor = GuildGovernor(payable(addresses.mainnet("DAO_GOVERNOR_GUILD")));
        vetoGuildGovernor = GuildVetoGovernor(
            payable(addresses.mainnet("ONBOARD_VETO_GUILD"))
        );
        vetoCreditGovernor = GuildVetoGovernor(
            payable(addresses.mainnet("ONBOARD_VETO_CREDIT"))
        );
        timelock = GuildTimelockController(
            payable(addresses.mainnet("DAO_TIMELOCK"))
        );

        /// lending terms
        onboarder = LendingTermOnboarding(
            payable(addresses.mainnet("ONBOARD_GOVERNOR_GUILD"))
        );
        offboarder = LendingTermOffboarding(
            addresses.mainnet("OFFBOARD_GOVERNOR_GUILD")
        );

        term = LendingTerm(addresses.mainnet("TERM_SDAI_1"));
        collateralToken = ERC20(term.getParameters().collateralToken);
        
        vm.label(userOne, "user one");
        vm.label(userTwo, "user two");
        vm.label(userThree, "user three");
        
        // Mint the first CREDIT tokens and enter rebase
        // Doing this with a non-dust balance ensures the share price internally
        // to the CreditToken has a reasonable size.
        {
            /// @notice USDC mint amount
            uint256 INITIAL_USDC_MINT_AMOUNT = 100 * 1e6;
            deal(address(usdc), userThree, INITIAL_USDC_MINT_AMOUNT);
            
            vm.startPrank(userThree);
            usdc.approve(address(psm), INITIAL_USDC_MINT_AMOUNT);
            psm.mint(userThree, INITIAL_USDC_MINT_AMOUNT);
            credit.enterRebase();
            vm.stopPrank();
        }
    }
}
