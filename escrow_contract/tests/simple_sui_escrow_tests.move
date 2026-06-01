#[test_only]
module escrow::escrow_tests;

use escrow::escrow;
use sui::test_scenario;

#[test]
fun test_create_escrow() {

    let mut scenario = test_scenario::begin(@0xA);

    {
        let ctx = test_scenario::ctx(&mut scenario);

        escrow::create_escrow(
            @0xA,
            @0xB,
            1000,
            b"Test Escrow",
            ctx
        );
    };

    // move to next transaction
    scenario.next_tx(@0xA);

    let escrow_obj =
        test_scenario::take_from_sender<escrow::Escrow>(&scenario);

    test_scenario::return_to_sender(
        &scenario,
        escrow_obj
    );

    test_scenario::end(scenario);
}