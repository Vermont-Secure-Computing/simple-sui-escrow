#[test_only]
module escrow::escrow_tests;

use std::option;
use sui::balance;
use sui::coin::{Self, Coin};
use sui::sui::SUI;

use escrow::escrow;
use sui::clock;
use sui::test_scenario;

// ============================================================
// Batch 1
// Basic escrow creation
// ============================================================

#[test]
fun test_create_escrow() {
    let creator = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(creator);

    // Create a Clock value specifically for this unit test.
    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    // --------------------------------------------------------
    // TX 1: Create escrow
    // --------------------------------------------------------

    escrow::create_escrow(
        0u8,                       // escrow_type
        option::some(creator),     // party_a
        option::some(party_b),     // party_b
        1000u64,                   // reference_amount
        1200u64,                   // required_deposit_a
        200u64,                    // required_deposit_b
        b"Test Escrow",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // --------------------------------------------------------
    // TX 2: Read shared Escrow
    // --------------------------------------------------------

    scenario.next_tx(creator);

    {
        let escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        assert!(
            escrow::creator(&escrow_obj) == creator,
            0
        );

        assert!(
            escrow::escrow_type(&escrow_obj) == 0u8,
            1
        );

        assert!(
            escrow::status(&escrow_obj) == 0u8,
            2
        );

        assert!(
            escrow::reference_amount(&escrow_obj) == 1000u64,
            3
        );

        assert!(
            escrow::required_deposit_a(&escrow_obj) == 1200u64,
            4
        );

        assert!(
            escrow::required_deposit_b(&escrow_obj) == 200u64,
            5
        );

        assert!(
            escrow::deposited_a(&escrow_obj) == 0u64,
            6
        );

        assert!(
            escrow::deposited_b(&escrow_obj) == 0u64,
            7
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 0u64,
            8
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Clock was created directly for testing, so destroy it directly.
    clock::destroy_for_testing(clock);

    test_scenario::end(scenario);

}

    #[test]
    fun test_deposit_both_parties() {
        let party_a = @0xA;
        let party_b = @0xB;

        let mut scenario = test_scenario::begin(party_a);

        let clock = clock::create_for_testing(
            test_scenario::ctx(&mut scenario)
        );

        // ========================================================
        // TX 1: Create escrow
        // ========================================================

        escrow::create_escrow(
            0u8,
            option::some(party_a),
            option::some(party_b),
            1000u64,
            1200u64,
            200u64,
            b"Deposit Test",
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // ========================================================
        // TX 2: Party A deposits 1200
        // ========================================================

        scenario.next_tx(party_a);

        {
            let mut escrow_obj =
                test_scenario::take_shared<escrow::Escrow>(&scenario);

            let coin_a = coin::mint_for_testing<SUI>(
                1200u64,
                test_scenario::ctx(&mut scenario),
            );

            escrow::deposit(
                &mut escrow_obj,
                coin_a,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::deposited_a(&escrow_obj) == 1200u64,
                10
            );

            assert!(
                escrow::deposited_b(&escrow_obj) == 0u64,
                11
            );

            assert!(
                escrow::vault_balance(&escrow_obj) == 1200u64,
                12
            );

            // Still CREATED because Party B has not deposited.
            assert!(
                escrow::status(&escrow_obj) == 0u8,
                13
            );

            test_scenario::return_shared(escrow_obj);
        };

        // ========================================================
        // TX 3: Party B deposits 200
        // ========================================================

        scenario.next_tx(party_b);

        {
            let mut escrow_obj =
                test_scenario::take_shared<escrow::Escrow>(&scenario);

            let coin_b = coin::mint_for_testing<SUI>(
                200u64,
                test_scenario::ctx(&mut scenario),
            );

            escrow::deposit(
                &mut escrow_obj,
                coin_b,
                &clock,
                test_scenario::ctx(&mut scenario),
            );

            assert!(
                escrow::deposited_a(&escrow_obj) == 1200u64,
                20
            );

            assert!(
                escrow::deposited_b(&escrow_obj) == 200u64,
                21
            );

            assert!(
                escrow::vault_balance(&escrow_obj) == 1400u64,
                22
            );

            // Both deposits complete.
            assert!(
                escrow::status(&escrow_obj) == 1u8,
                23
            );

            test_scenario::return_shared(escrow_obj);
        };

        clock::destroy_for_testing(clock);

        test_scenario::end(scenario);
}

// ============================================================
// Batch 2
// Deposit security tests
// ============================================================

// ------------------------------------------------------------
// Wrong deposit amount must fail.
// Party A requires 1200, but attempts to deposit 1199.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 6, location = escrow)]
fun test_wrong_deposit_amount() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Wrong Deposit Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let bad_coin = coin::mint_for_testing<SUI>(
        1199u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        bad_coin,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Expected to abort before reaching here.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Duplicate deposit must fail.
// Party A successfully deposits once, then attempts again.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 5, location = escrow)]
fun test_duplicate_deposit() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Duplicate Deposit Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // First Party A deposit.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Party A attempts a second deposit.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let duplicate_coin = coin::mint_for_testing<SUI>(
        1200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        duplicate_coin,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Expected to abort.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Third-party wallet cannot deposit when both party slots
// are already assigned.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_unauthorized_depositor() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized Deposit Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Attacker attempts to deposit.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let attacker_coin = coin::mint_for_testing<SUI>(
        1200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        attacker_coin,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Expected to abort.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Open Party B slot can be claimed by another wallet.
// Party A is known at creation.
// Party B = None.
// @0xB deposits required B amount and becomes Party B.
// ------------------------------------------------------------

#[test]
fun test_open_party_claim() {
    let party_a = @0xA;
    let new_party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::none<address>(),
        1000u64,
        1200u64,
        200u64,
        b"Open Party Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // --------------------------------------------------------
    // Party A deposits first.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::deposited_a(&escrow_obj) == 1200u64,
            100
        );

        assert!(
            escrow::deposited_b(&escrow_obj) == 0u64,
            101
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1200u64,
            102
        );

        assert!(
            escrow::status(&escrow_obj) == 0u8,
            103
        );

        test_scenario::return_shared(escrow_obj);
    };

    // --------------------------------------------------------
    // @0xB claims open Party B slot by depositing 200.
    // --------------------------------------------------------

    scenario.next_tx(new_party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::deposited_a(&escrow_obj) == 1200u64,
            110
        );

        assert!(
            escrow::deposited_b(&escrow_obj) == 200u64,
            111
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            112
        );

        assert!(
            escrow::status(&escrow_obj) == 1u8,
            113
        );

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);

    test_scenario::end(scenario);
}

// ============================================================
// Batch 3
// Finalization proposal + rejection security tests
// ============================================================

// ------------------------------------------------------------
// Valid finalization proposal.
// A deposits 1200, B deposits 200.
// Total locked = 1400.
// Proposed settlement:
//   A = 1000
//   B = 300
//   Donation = 100
// ------------------------------------------------------------

#[test]
fun test_suggest_finalization() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Finalization Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Party A deposit
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Party B deposit
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 1u8, 200);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 201);

        test_scenario::return_shared(escrow_obj);
    };

    // Party A proposes finalization
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement proposal",
            test_scenario::ctx(&mut scenario),
        );

        // FINALIZATION_SUGGESTED
        assert!(escrow::status(&escrow_obj) == 2u8, 202);

        // Funds must still remain locked.
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 203);

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Invalid finalization total.
//
// Locked = 1400
// Proposed = 1000 + 200 + 100 = 1300
//
// Must abort E_INVALID_FINALIZATION = 8.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 8, location = escrow)]
fun test_invalid_finalization_total() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Invalid Finalization Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    // 1000 + 200 + 100 = 1300
    // But vault contains 1400.
    escrow::suggest_finalization(
        &mut escrow_obj,
        1000u64,
        200u64,
        100u64,
        b"Bad settlement",
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Donation cannot exceed reference_amount.
//
// reference_amount = 1000
// donation = 1001
//
// Total still equals 1400:
//   A = 199
//   B = 200
//   donation = 1001
//
// Must abort E_INVALID_DONATION = 11.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 11, location = escrow)]
fun test_donation_above_reference() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Donation Limit Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        199u64,
        200u64,
        1001u64,
        b"Donation too large",
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Proposer cannot reject their own proposal.
//
// Must abort E_CANNOT_REJECT_OWN_FINALIZATION = 10.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 10, location = escrow)]
fun test_proposer_cannot_reject() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Self Reject Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposit
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposit
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A tries to reject own proposal.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::reject_finalization(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Other party CAN reject.
//
// A proposes.
// B rejects.
//
// Escrow should return to DEPOSITS_COMPLETE.
// Funds must remain untouched.
// ------------------------------------------------------------

#[test]
fun test_other_party_can_reject() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Reject Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposit
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposit
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Proposal",
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 2u8, 300);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 301);

        test_scenario::return_shared(escrow_obj);
    };

    // B rejects
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::reject_finalization(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        // Back to DEPOSITS_COMPLETE.
        assert!(escrow::status(&escrow_obj) == 1u8, 302);

        // No funds should move during rejection.
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 303);

        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 304);
        assert!(escrow::deposited_b(&escrow_obj) == 200u64, 305);

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 4
// Finalization acceptance + payout security
// ============================================================

// ------------------------------------------------------------
// Proposer cannot accept their own proposal.
//
// Party A proposes settlement.
// Party A then attempts to accept it.
//
// Must abort:
// E_CANNOT_ACCEPT_OWN_FINALIZATION = 9
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 9, location = escrow)]
fun test_proposer_cannot_accept() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    // ========================================================
    // TX 1: Create escrow
    // ========================================================

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Self Accept Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // ========================================================
    // TX 2: Party A deposits 1200
    // ========================================================

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 3: Party B deposits 200
    // ========================================================

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 4: Party A proposes settlement
    // ========================================================

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement proposal",
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 2u8,
            400
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            401
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 5: Party A tries to accept own proposal
    // Must abort with code 9.
    // ========================================================

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::accept_finalization(
        &mut escrow_obj,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort before reaching here.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Other party accepts valid finalization.
//
// A deposits = 1200
// B deposits = 200
// Total locked = 1400
//
// Settlement:
//   Party A  = 1000
//   Party B  = 300
//   Donation = 100
//
// Party A proposes.
// Party B accepts.
//
// Expected:
//   status = COMPLETED (3)
//   vault = 0
//
// Actual transferred Coin<SUI> objects:
//   @0xA = 1000
//   @0xB = 300
//   @0xD = 100
// ------------------------------------------------------------

#[test]
fun test_other_party_accepts_and_payouts() {
    let party_a = @0xA;
    let party_b = @0xB;
    let donation_recipient = @0xD;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    // ========================================================
    // TX 1: Create escrow
    // ========================================================

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Acceptance Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // ========================================================
    // TX 2: Party A deposits 1200
    // ========================================================

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 3: Party B deposits 200
    // ========================================================

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 1u8,
            410
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            411
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 4: Party A proposes
    //
    // 1000 + 300 + 100 = 1400
    // ========================================================

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Final settlement",
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 2u8,
            412
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            413
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // TX 5: Party B accepts
    // ========================================================

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        // Escrow must now be COMPLETED.
        assert!(
            escrow::status(&escrow_obj) == 3u8,
            414
        );

        // Entire vault must have been distributed.
        assert!(
            escrow::vault_balance(&escrow_obj) == 0u64,
            415
        );

        test_scenario::return_shared(escrow_obj);
    };

    // ========================================================
    // Verify Party A payout
    // ========================================================

    scenario.next_tx(party_a);

    {
        let payout_a =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(
            coin::value(&payout_a) == 1000u64,
            416
        );

        coin::burn_for_testing(payout_a);
    };

    // ========================================================
    // Verify Party B payout
    // ========================================================

    scenario.next_tx(party_b);

    {
        let payout_b =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(
            coin::value(&payout_b) == 300u64,
            417
        );

        coin::burn_for_testing(payout_b);
    };

    // ========================================================
    // Verify hardcoded donation recipient payout
    // ========================================================

    scenario.next_tx(donation_recipient);

    {
        let donation =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(
            coin::value(&donation) == 100u64,
            418
        );

        coin::burn_for_testing(donation);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 5
// Withdraw-before-complete / cancellation security
// ============================================================

// ------------------------------------------------------------
// Party A deposits, then withdraws before Party B deposits.
//
// Expected:
//   A gets 1200 back
//   vault = 0
//   status = CANCELLED (4)
// ------------------------------------------------------------

#[test]
fun test_withdraw_before_complete() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    // Create escrow.
    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Withdraw Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // --------------------------------------------------------
    // Party A deposits 1200.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1200u64,
            500
        );

        assert!(
            escrow::status(&escrow_obj) == 0u8,
            501
        );

        test_scenario::return_shared(escrow_obj);
    };

    // --------------------------------------------------------
    // Party A withdraws before completion.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::withdraw_before_complete(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 4u8,
            502
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 0u64,
            503
        );

        test_scenario::return_shared(escrow_obj);
    };

    // --------------------------------------------------------
    // Verify actual refund Coin<SUI> received by Party A.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    {
        let refund =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(
            coin::value(&refund) == 1200u64,
            504
        );

        coin::burn_for_testing(refund);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Party B cannot withdraw when Party B deposited nothing.
//
// A has deposited 1200.
// B is a legitimate party, but has deposited 0.
//
// Must abort E_NOTHING_TO_WITHDRAW = 7.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 7, location = escrow)]
fun test_party_with_no_deposit_cannot_withdraw() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"No Deposit Withdraw Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B has deposited nothing but attempts withdrawal.
    scenario.next_tx(party_b);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::withdraw_before_complete(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Unauthorized third party cannot withdraw.
//
// A deposits 1200.
// Attacker @0xC attempts withdrawal.
//
// Must abort E_UNAUTHORIZED = 3.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_unauthorized_withdraw() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized Withdraw Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Attacker attempts withdrawal.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::withdraw_before_complete(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Withdrawal is no longer allowed after both deposits complete.
//
// A = 1200
// B = 200
// status becomes DEPOSITS_COMPLETE.
//
// A attempts withdraw_before_complete.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_cannot_withdraw_after_deposits_complete() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Late Withdraw Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // --------------------------------------------------------
    // A deposits.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // --------------------------------------------------------
    // B deposits.
    // --------------------------------------------------------

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 1u8,
            510
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            511
        );

        test_scenario::return_shared(escrow_obj);
    };

    // --------------------------------------------------------
    // A attempts late withdrawal.
    // --------------------------------------------------------

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::withdraw_before_complete(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 6
// Boundary + state-machine security
// ============================================================

// ------------------------------------------------------------
// Helper: create a vector<u8> containing `len` bytes.
// ------------------------------------------------------------

fun make_test_bytes(len: u64): vector<u8> {
    let mut bytes = vector[];

    let mut i = 0u64;
    while (i < len) {
        vector::push_back(&mut bytes, 65u8); // ASCII 'A'
        i = i + 1;
    };

    bytes
}


// ------------------------------------------------------------
// Create escrow note exactly 200 bytes.
// Must succeed.
// ------------------------------------------------------------

#[test]
fun test_create_note_exactly_200_bytes() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    let note = make_test_bytes(200u64);

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        note,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        assert!(
            escrow::status(&escrow_obj) == 0u8,
            600
        );

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Create escrow note 201 bytes.
// Must abort E_NOTE_TOO_LONG = 1.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 1, location = escrow)]
fun test_create_note_201_bytes_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    let note = make_test_bytes(201u64);

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        note,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// reference_amount = 0.
// Must abort E_INVALID_AMOUNT = 0.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 0, location = escrow)]
fun test_zero_reference_amount_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        0u64,
        1200u64,
        200u64,
        b"Zero Reference",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// required_deposit_a = 0.
// Must abort E_INVALID_AMOUNT = 0.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 0, location = escrow)]
fun test_zero_deposit_a_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        0u64,
        200u64,
        b"Zero Deposit A",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// required_deposit_b = 0.
// Must abort E_INVALID_AMOUNT = 0.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 0, location = escrow)]
fun test_zero_deposit_b_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        0u64,
        b"Zero Deposit B",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Party A and Party B cannot be same address.
// Must abort E_INVALID_PARTY = 2.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 2, location = escrow)]
fun test_same_parties_rejected() {
    let party_a = @0xA;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_a),
        1000u64,
        1200u64,
        200u64,
        b"Same Parties",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Creator must be Party A or Party B when both are assigned.
//
// Creator = C
// A = A
// B = B
//
// Must abort E_UNAUTHORIZED = 3.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_creator_not_party_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;
    let creator = @0xC;

    let mut scenario = test_scenario::begin(creator);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized Creator",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Both party slots cannot be empty.
// Must abort E_INVALID_PARTY = 2.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 2, location = escrow)]
fun test_both_parties_none_rejected() {
    let creator = @0xA;

    let mut scenario = test_scenario::begin(creator);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::none<address>(),
        option::none<address>(),
        1000u64,
        1200u64,
        200u64,
        b"No Parties",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Deposit after escrow was CANCELLED.
//
// A deposits then withdraws.
// A attempts to deposit again.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_deposit_after_cancel_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Cancelled Deposit Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A withdraws -> CANCELLED.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::withdraw_before_complete(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 4u8,
            610
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Consume refund so test scenario stays clean.
    scenario.next_tx(party_a);

    {
        let refund =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(
            coin::value(&refund) == 1200u64,
            611
        );

        coin::burn_for_testing(refund);
    };

    // Attempt another deposit after CANCELLED.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let new_coin = coin::mint_for_testing<SUI>(
        1200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        new_coin,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// suggest_finalization after CANCELLED.
//
// A deposits then withdraws.
// Escrow becomes CANCELLED.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_suggest_after_cancel_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Cancelled Suggest Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A cancels.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::withdraw_before_complete(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 4u8,
            620
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Consume refund.
    scenario.next_tx(party_a);

    {
        let refund =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        coin::burn_for_testing(refund);
    };

    // A attempts finalization proposal on cancelled escrow.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        1000u64,
        300u64,
        100u64,
        b"Should fail",
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Finalization note exactly 200 bytes.
// Must succeed.
// ------------------------------------------------------------

#[test]
fun test_finalization_note_exactly_200_bytes() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Finalization Note Boundary",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposit.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposit.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes with exactly 200-byte note.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let final_note = make_test_bytes(200u64);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            final_note,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 2u8,
            630
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            631
        );

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Finalization note 201 bytes.
// Must abort E_NOTE_TOO_LONG = 1.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 1, location = escrow)]
fun test_finalization_note_201_bytes_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Long Finalization Note",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposit.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposit.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes with 201-byte note.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let final_note = make_test_bytes(201u64);

    escrow::suggest_finalization(
        &mut escrow_obj,
        1000u64,
        300u64,
        100u64,
        final_note,
        test_scenario::ctx(&mut scenario),
    );

    // Expected abort.
    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Arithmetic overflow during finalization.
//
// Locked:
//   A = U64_MAX
//   B = 1
//
// Computing deposited_a + deposited_b must be protected.
//
// Must abort E_ARITHMETIC_OVERFLOW = 12.
// ------------------------------------------------------------

#[test]
#[expected_failure(arithmetic_error, location = sui::balance)]
fun test_finalization_arithmetic_overflow_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let max_u64 = 18446744073709551615u64;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        max_u64,
        1u64,
        b"Overflow Test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits U64_MAX.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            max_u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposits 1.
    //
    // Depending on where checked arithmetic is performed,
    // the protected overflow may trigger here or when the
    // finalization total is calculated.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            1u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // If deposit succeeded, trigger checked total calculation.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        max_u64,
        0u64,
        1u64,
        b"Overflow settlement",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 7
// Finalization state machine + contract arithmetic security
// ============================================================


// ------------------------------------------------------------
// payout_a + payout_b overflows u64.
//
// Vault itself is only 1400, so this reaches OUR checked
// payout arithmetic rather than overflowing sui::balance.
//
// Expected: E_ARITHMETIC_OVERFLOW = 12.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 12, location = escrow)]
fun test_payout_ab_arithmetic_overflow_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;
    let max_u64 = 18446744073709551615u64;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Payout overflow",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposits.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A submits malicious payout values:
    //
    // U64_MAX + 1
    //
    // Must be caught by escrow's checked arithmetic.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        max_u64,
        1u64,
        0u64,
        b"Overflow",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// payout_a + payout_b succeeds, but adding donation overflows.
//
// payout_a = U64_MAX - 1
// payout_b = 1
//
// subtotal = U64_MAX
//
// donation = 1
//
// U64_MAX + 1 must abort with OUR error 12.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 12, location = escrow)]
fun test_payout_plus_donation_overflow_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let max_minus_one = 18446744073709551614u64;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Donation overflow",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        max_minus_one,
        1u64,
        1u64,
        b"Overflow donation",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Cannot create a second proposal while one is active.
//
// First proposal changes state:
//   DEPOSITS_COMPLETE -> FINALIZATION_SUGGESTED
//
// Second suggest must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_second_active_proposal_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Second proposal",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // First proposal.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Proposal one",
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 2u8,
            700
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B tries to overwrite active proposal.
    scenario.next_tx(party_b);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        700u64,
        600u64,
        100u64,
        b"Proposal two",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Deposit cannot occur while finalization proposal is active.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_deposit_during_finalization_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Deposit during proposal",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Active proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Try another deposit while status = 2.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let payment = coin::mint_for_testing<SUI>(
        1200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        payment,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Withdrawal cannot occur while finalization is suggested.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_withdraw_during_finalization_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Withdraw during proposal",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Active proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A tries withdrawal while proposal is active.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::withdraw_before_complete(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// After rejection, old proposal cannot be accepted.
//
// Flow:
//   A proposes
//   B rejects
//   status returns to DEPOSITS_COMPLETE
//   B then tries accept_finalization
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_accept_after_rejection_rejected() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Reject then accept",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B rejects.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::reject_finalization(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 1u8,
            710
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B tries to accept the OLD proposal.
    scenario.next_tx(party_b);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::accept_finalization(
        &mut escrow_obj,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// After a rejection, a NEW proposal should be allowed.
//
// Flow:
//   A proposes
//   B rejects
//   B creates a new proposal
//
// Expected:
//   status = FINALIZATION_SUGGESTED
//
// This verifies rejection doesn't permanently lock the escrow.
// ------------------------------------------------------------

#[test]
fun test_new_proposal_after_rejection_allowed() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Reproposal test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"First proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B rejects.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::reject_finalization(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 1u8,
            720
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B now creates a new proposal.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            700u64,
            600u64,
            100u64,
            b"Second proposal",
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 2u8,
            721
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 1400u64,
            722
        );

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 8
// COMPLETED state security / terminal-state tests
// ============================================================


// ------------------------------------------------------------
// Helper pattern for this batch:
//
// Every test independently creates:
//   A deposit = 1200
//   B deposit = 200
//   A proposes 1000 / 300 / 100
//   B accepts
//
// Escrow is then STATUS_COMPLETED = 3.
// ------------------------------------------------------------


// ------------------------------------------------------------
// Completed escrow cannot accept again.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_completed_escrow_cannot_accept_again() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Completed accept test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B deposits.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B accepts.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 800);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 801);

        test_scenario::return_shared(escrow_obj);
    };

    // A attempts a second accept.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::accept_finalization(
        &mut escrow_obj,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Completed escrow cannot reject.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_completed_escrow_cannot_reject() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Completed reject test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 810);

        test_scenario::return_shared(escrow_obj);
    };

    // Cannot reject an already completed settlement.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::reject_finalization(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Completed escrow cannot create another proposal.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_completed_escrow_cannot_suggest_again() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Completed suggest test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 820);

        test_scenario::return_shared(escrow_obj);
    };

    // Try to create a fresh proposal after completion.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        1000u64,
        300u64,
        100u64,
        b"Second settlement",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Completed escrow cannot receive another deposit.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_completed_escrow_cannot_deposit() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Completed deposit test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 830);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 831);

        test_scenario::return_shared(escrow_obj);
    };

    // Try to deposit after settlement.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let payment = coin::mint_for_testing<SUI>(
        1200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        payment,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Completed escrow cannot withdraw.
//
// Vault is already zero, but STATUS check should reject first.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_completed_escrow_cannot_withdraw() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Completed withdraw test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 840);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 841);

        test_scenario::return_shared(escrow_obj);
    };

    // Try withdrawal after completion.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::withdraw_before_complete(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Verify terminal state after successful settlement.
//
// Expected:
//   status       = COMPLETED (3)
//   vault        = 0
//   deposited_a  = 1200
//   deposited_b  = 200
//   finalized_at > 0
//
// This confirms the completed Escrow object remains useful
// as an immutable-style historical record.
// ------------------------------------------------------------

#[test]
fun test_completed_escrow_terminal_state() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let mut clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    // Give the test clock a non-zero timestamp so finalized_at
    // can be meaningfully checked.
    clock::increment_for_testing(&mut clock, 1000u64);

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Terminal state test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Final settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Advance time again before acceptance.
    clock::increment_for_testing(&mut clock, 1000u64);

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(
            escrow::status(&escrow_obj) == 3u8,
            850
        );

        assert!(
            escrow::vault_balance(&escrow_obj) == 0u64,
            851
        );

        assert!(
            escrow::deposited_a(&escrow_obj) == 1200u64,
            852
        );

        assert!(
            escrow::deposited_b(&escrow_obj) == 200u64,
            853
        );

        assert!(
            escrow::finalized_at(&escrow_obj) > 0u64,
            854
        );

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 9
// Open-party + authorization security tests
// ============================================================


// ------------------------------------------------------------
// Creator cannot claim the other open party slot.
//
// Party A = creator
// Party B = None
//
// A deposits as Party A first.
// A then tries to deposit Party B amount.
//
// Must NOT allow one wallet to become both parties.
// Expected: E_INVALID_STATUS or E_ALREADY_DEPOSITED depending
// on the deposit validation order.
//
// Current expected contract behavior:
// E_ALREADY_DEPOSITED = 5.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 5, location = escrow)]
fun test_creator_cannot_claim_open_other_party_slot() {
    let party_a = @0xA;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::none<address>(),
        1000u64,
        1200u64,
        200u64,
        b"Creator double role test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A makes legitimate Party A deposit.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // A now tries to claim the still-open B slot.
    scenario.next_tx(party_a);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let fake_b_deposit = coin::mint_for_testing<SUI>(
        200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        fake_b_deposit,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Once open Party B is claimed, another wallet cannot replace it.
//
// A = @0xA
// B initially None
// @0xB claims B by depositing 200.
//
// @0xC then attempts another deposit.
//
// Both deposits are already complete, therefore status is
// DEPOSITS_COMPLETE.
//
// Must abort E_INVALID_STATUS = 4.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 4, location = escrow)]
fun test_claimed_open_party_cannot_be_replaced() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::none<address>(),
        1000u64,
        1200u64,
        200u64,
        b"Claim lock test",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B claims open Party B slot.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 1u8, 900);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 901);

        test_scenario::return_shared(escrow_obj);
    };

    // Attacker attempts to replace/claim B.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    let attacker_coin = coin::mint_for_testing<SUI>(
        200u64,
        test_scenario::ctx(&mut scenario),
    );

    escrow::deposit(
        &mut escrow_obj,
        attacker_coin,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Unauthorized wallet cannot suggest finalization.
//
// A and B are fully deposited.
// C attempts to create settlement.
//
// Must abort E_UNAUTHORIZED = 3.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_unauthorized_suggest_finalization() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized proposal",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // C attempts proposal.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::suggest_finalization(
        &mut escrow_obj,
        1000u64,
        300u64,
        100u64,
        b"Attacker settlement",
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Unauthorized wallet cannot reject an active proposal.
//
// A proposes.
// C attempts rejection.
//
// Must abort E_UNAUTHORIZED = 3.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_unauthorized_reject_finalization() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized reject",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Valid settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // C tries rejection.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::reject_finalization(
        &mut escrow_obj,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Unauthorized wallet cannot accept active proposal.
//
// A proposes.
// C attempts acceptance.
//
// Must abort E_UNAUTHORIZED = 3.
// ------------------------------------------------------------

#[test]
#[expected_failure(abort_code = 3, location = escrow)]
fun test_unauthorized_accept_finalization() {
    let party_a = @0xA;
    let party_b = @0xB;
    let attacker = @0xC;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Unauthorized accept",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Valid settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // C attempts acceptance.
    scenario.next_tx(attacker);

    let mut escrow_obj =
        test_scenario::take_shared<escrow::Escrow>(&scenario);

    escrow::accept_finalization(
        &mut escrow_obj,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::return_shared(escrow_obj);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Full open-party lifecycle.
//
// A creates escrow with Party B = None.
// A deposits.
// B claims open slot by depositing.
// B proposes.
// A accepts.
//
// Expected:
//   status = COMPLETED
//   vault = 0
//
// Settlement:
//   A = 1000
//   B = 300
//   Donation = 100
// ------------------------------------------------------------

#[test]
fun test_open_party_full_lifecycle() {
    let party_a = @0xA;
    let party_b = @0xB;
    let donation_recipient = @0xD;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::none<address>(),
        1000u64,
        1200u64,
        200u64,
        b"Open party lifecycle",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 0u8, 920);
        assert!(escrow::vault_balance(&escrow_obj) == 1200u64, 921);

        test_scenario::return_shared(escrow_obj);
    };

    // B claims open slot.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 1u8, 922);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 923);

        test_scenario::return_shared(escrow_obj);
    };

    // B proposes.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Open party settlement",
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 2u8, 924);

        test_scenario::return_shared(escrow_obj);
    };

    // A accepts.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 925);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 926);

        test_scenario::return_shared(escrow_obj);
    };

    // Verify A payout.
    scenario.next_tx(party_a);

    {
        let payout_a =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(coin::value(&payout_a) == 1000u64, 927);

        coin::burn_for_testing(payout_a);
    };

    // Verify claimed Party B payout.
    scenario.next_tx(party_b);

    {
        let payout_b =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(coin::value(&payout_b) == 300u64, 928);

        coin::burn_for_testing(payout_b);
    };

    // Verify donation.
    scenario.next_tx(donation_recipient);

    {
        let donation =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(coin::value(&donation) == 100u64, 929);

        coin::burn_for_testing(donation);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ============================================================
// Batch 10
// Final audit-style invariants
// ============================================================


// ------------------------------------------------------------
// escrow_type must persist through the full lifecycle.
//
// escrow_type is metadata only in V1, but it must not change
// during deposits, proposal, or completion.
// ------------------------------------------------------------

#[test]
fun test_escrow_type_persists_through_completion() {
    let party_a = @0xA;
    let party_b = @0xB;
    let donation_recipient = @0xD;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        77u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Escrow type persistence",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Verify initial type.
    scenario.next_tx(party_a);

    {
        let escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        assert!(escrow::escrow_type(&escrow_obj) == 77u8, 1000);
        assert!(escrow::status(&escrow_obj) == 0u8, 1001);

        test_scenario::return_shared(escrow_obj);
    };

    // A deposits.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_a = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_a,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::escrow_type(&escrow_obj) == 77u8, 1002);

        test_scenario::return_shared(escrow_obj);
    };

    // B deposits.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let coin_b = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            coin_b,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 1u8, 1003);
        assert!(escrow::escrow_type(&escrow_obj) == 77u8, 1004);

        test_scenario::return_shared(escrow_obj);
    };

    // A proposes.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 2u8, 1005);
        assert!(escrow::escrow_type(&escrow_obj) == 77u8, 1006);

        test_scenario::return_shared(escrow_obj);
    };

    // B accepts.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 1007);
        assert!(escrow::escrow_type(&escrow_obj) == 77u8, 1008);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 1009);

        test_scenario::return_shared(escrow_obj);
    };

    // Consume transferred coins.
    scenario.next_tx(party_a);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(party_b);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(donation_recipient);
    {
        let donation =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(donation);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Deposited accounting must remain unchanged after settlement.
//
// Settlement transfers the vault, but historical deposited_a
// and deposited_b values must remain intact.
// ------------------------------------------------------------

#[test]
fun test_deposit_accounting_preserved_after_completion() {
    let party_a = @0xA;
    let party_b = @0xB;
    let donation_recipient = @0xD;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Accounting persistence",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 1010);
        assert!(escrow::deposited_b(&escrow_obj) == 200u64, 1011);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 1012);

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 1013);

        // Vault was distributed.
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 1014);

        // Historical accounting remains.
        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 1015);
        assert!(escrow::deposited_b(&escrow_obj) == 200u64, 1016);

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(party_b);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(donation_recipient);
    {
        let donation =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(donation);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Rejection must not change deposit accounting or vault.
//
// A proposes.
// B rejects.
//
// Expected:
//   status      = DEPOSITS_COMPLETE
//   vault       = 1400
//   deposited_a = 1200
//   deposited_b = 200
//
// A new proposal must then still use the full 1400.
// ------------------------------------------------------------

#[test]
fun test_rejection_preserves_full_accounting() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Reject accounting",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // First proposal.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"First proposal",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // B rejects.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::reject_finalization(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 1u8, 1020);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 1021);
        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 1022);
        assert!(escrow::deposited_b(&escrow_obj) == 200u64, 1023);

        test_scenario::return_shared(escrow_obj);
    };

    // B can make a completely new valid proposal
    // using the original full locked balance.
    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            700u64,
            600u64,
            100u64,
            b"Second proposal",
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 2u8, 1024);
        assert!(escrow::vault_balance(&escrow_obj) == 1400u64, 1025);
        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 1026);
        assert!(escrow::deposited_b(&escrow_obj) == 200u64, 1027);

        test_scenario::return_shared(escrow_obj);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// Cancellation must permanently lock the escrow state.
//
// A deposits then cancels.
// After refund:
//   status = CANCELLED
//   vault  = 0
//
// Historical deposited_a currently remains 1200.
// This test documents that behavior.
// ------------------------------------------------------------

#[test]
fun test_cancelled_terminal_accounting() {
    let party_a = @0xA;
    let party_b = @0xB;

    let mut scenario = test_scenario::begin(party_a);

    let clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Cancelled accounting",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::deposited_a(&escrow_obj) == 1200u64, 1030);
        assert!(escrow::vault_balance(&escrow_obj) == 1200u64, 1031);

        test_scenario::return_shared(escrow_obj);
    };

    // Cancel.
    scenario.next_tx(party_a);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::withdraw_before_complete(
            &mut escrow_obj,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 4u8, 1032);
        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 1033);

        test_scenario::return_shared(escrow_obj);
    };

    // Verify exact refund.
    scenario.next_tx(party_a);

    {
        let refund =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);

        assert!(coin::value(&refund) == 1200u64, 1034);

        coin::burn_for_testing(refund);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}


// ------------------------------------------------------------
// finalized_at must reflect the Clock used at acceptance.
//
// We advance the test clock before accepting.
// finalized_at must therefore be non-zero.
// ------------------------------------------------------------

#[test]
fun test_finalized_timestamp_written_on_acceptance() {
    let party_a = @0xA;
    let party_b = @0xB;
    let donation_recipient = @0xD;

    let mut scenario = test_scenario::begin(party_a);

    let mut clock = clock::create_for_testing(
        test_scenario::ctx(&mut scenario)
    );

    escrow::create_escrow(
        0u8,
        option::some(party_a),
        option::some(party_b),
        1000u64,
        1200u64,
        200u64,
        b"Timestamp audit",
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            1200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_b);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        let payment = coin::mint_for_testing<SUI>(
            200u64,
            test_scenario::ctx(&mut scenario),
        );

        escrow::deposit(
            &mut escrow_obj,
            payment,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    scenario.next_tx(party_a);
    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::suggest_finalization(
            &mut escrow_obj,
            1000u64,
            300u64,
            100u64,
            b"Timestamp settlement",
            test_scenario::ctx(&mut scenario),
        );

        test_scenario::return_shared(escrow_obj);
    };

    // Move Clock forward before settlement.
    clock::increment_for_testing(&mut clock, 5000u64);

    scenario.next_tx(party_b);

    {
        let mut escrow_obj =
            test_scenario::take_shared<escrow::Escrow>(&scenario);

        escrow::accept_finalization(
            &mut escrow_obj,
            &clock,
            test_scenario::ctx(&mut scenario),
        );

        assert!(escrow::status(&escrow_obj) == 3u8, 1040);

        assert!(
            escrow::finalized_at(&escrow_obj) > 0u64,
            1041
        );

        assert!(escrow::vault_balance(&escrow_obj) == 0u64, 1042);

        test_scenario::return_shared(escrow_obj);
    };

    // Clean payout objects.
    scenario.next_tx(party_a);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(party_b);
    {
        let payout =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(payout);
    };

    scenario.next_tx(donation_recipient);
    {
        let donation =
            test_scenario::take_from_sender<Coin<SUI>>(&scenario);
        coin::burn_for_testing(donation);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}