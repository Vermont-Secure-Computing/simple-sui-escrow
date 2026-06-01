module escrow::escrow {

    use std::option::{Self, Option};
    use std::vector;

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    const STATUS_CREATED: u8 = 0;
    const STATUS_FUNDED: u8 = 1;

    const E_INVALID_AMOUNT: u64 = 0;
    const E_NOTE_TOO_LONG: u64 = 1;
    const E_INVALID_PARTY: u64 = 2;
    const E_UNAUTHORIZED: u64 = 3;
    const E_INVALID_STATUS: u64 = 4;
    const E_ALREADY_DEPOSITED: u64 = 5;
    const E_INVALID_DEPOSIT_AMOUNT: u64 = 6;
    const E_NOT_FUNDED: u64 = 7;

    const MAX_NOTE_LEN: u64 = 200;

    public struct Escrow has key {
        id: UID,

        creator: address,

        buyer: address,
        seller: address,

        price: u64,
        buyer_bond: u64,
        seller_bond: u64,

        buyer_required: u64,
        seller_required: u64,

        buyer_coin: Option<Coin<SUI>>,
        seller_coin: Option<Coin<SUI>>,

        buyer_deposited: bool,
        seller_deposited: bool,

        status: u8,

        note: vector<u8>,
    }

    public fun create_escrow(
        buyer: address,
        seller: address,
        price: u64,
        buyer_bond: u64,
        seller_bond: u64,
        note: vector<u8>,
        ctx: &mut TxContext
    ) {
        assert!(price > 0, E_INVALID_AMOUNT);
        assert!(buyer_bond > 0, E_INVALID_AMOUNT);
        assert!(seller_bond > 0, E_INVALID_AMOUNT);
        assert!(vector::length(&note) <= MAX_NOTE_LEN, E_NOTE_TOO_LONG);
        assert!(buyer != seller, E_INVALID_PARTY);

        let creator = tx_context::sender(ctx);

        // optional rule: only buyer or seller can create
        assert!(
            creator == buyer || creator == seller,
            E_UNAUTHORIZED
        );

        let buyer_required = price + buyer_bond;
        let seller_required = seller_bond;

        let escrow = Escrow {
            id: object::new(ctx),

            creator,

            buyer,
            seller,

            price,
            buyer_bond,
            seller_bond,

            buyer_required,
            seller_required,

            buyer_coin: option::none<Coin<SUI>>(),
            seller_coin: option::none<Coin<SUI>>(),

            buyer_deposited: false,
            seller_deposited: false,

            status: STATUS_CREATED,

            note,
        };

        // shared object so both buyer and seller can interact
        transfer::share_object(escrow);
    }

    public fun deposit_buyer(
        escrow: &mut Escrow,
        coin: Coin<SUI>,
        ctx: &TxContext
    ) {
        assert!(escrow.status == STATUS_CREATED, E_INVALID_STATUS);
        assert!(tx_context::sender(ctx) == escrow.buyer, E_UNAUTHORIZED);
        assert!(!escrow.buyer_deposited, E_ALREADY_DEPOSITED);
        assert!(coin::value(&coin) == escrow.buyer_required, E_INVALID_DEPOSIT_AMOUNT);

        option::fill(&mut escrow.buyer_coin, coin);
        escrow.buyer_deposited = true;

        if (escrow.seller_deposited) {
            escrow.status = STATUS_FUNDED;
        };
    }

    public fun deposit_seller(
        escrow: &mut Escrow,
        coin: Coin<SUI>,
        ctx: &TxContext
    ) {
        assert!(escrow.status == STATUS_CREATED, E_INVALID_STATUS);
        assert!(tx_context::sender(ctx) == escrow.seller, E_UNAUTHORIZED);
        assert!(!escrow.seller_deposited, E_ALREADY_DEPOSITED);
        assert!(coin::value(&coin) == escrow.seller_required, E_INVALID_DEPOSIT_AMOUNT);

        option::fill(&mut escrow.seller_coin, coin);
        escrow.seller_deposited = true;

        if (escrow.buyer_deposited) {
            escrow.status = STATUS_FUNDED;
        };
    }

    // Buyer confirms successful purchase.
    // Seller receives price + buyer bond.
    // Buyer receives seller bond.
    public fun release(
        escrow: Escrow,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == escrow.buyer, E_UNAUTHORIZED);
        assert!(escrow.status == STATUS_FUNDED, E_NOT_FUNDED);

        let Escrow {
            id,
            creator: _,
            buyer,
            seller,
            price,
            buyer_bond,
            seller_bond: _,
            buyer_required: _,
            seller_required: _,
            buyer_coin,
            seller_coin,
            buyer_deposited: _,
            seller_deposited: _,
            status: _,
            note: _,
        } = escrow;

        let mut buyer_coin = option::destroy_some(buyer_coin);
        let seller_coin = option::destroy_some(seller_coin);

        coin::join(&mut buyer_coin, seller_coin);

        let seller_gets = price + buyer_bond;

        let seller_payout = coin::split(&mut buyer_coin, seller_gets, ctx);

        transfer::public_transfer(seller_payout, seller);

        // remaining coin is seller bond, returned to buyer
        transfer::public_transfer(buyer_coin, buyer);

        object::delete(id);
    }

    // Seller agrees to refund.
    // Buyer receives everything.
    public fun refund(
        escrow: Escrow,
        ctx: &mut TxContext
    ) {
        assert!(tx_context::sender(ctx) == escrow.seller, E_UNAUTHORIZED);
        assert!(escrow.status == STATUS_FUNDED, E_NOT_FUNDED);

        let Escrow {
            id,
            creator: _,
            buyer,
            seller: _,
            price: _,
            buyer_bond: _,
            seller_bond: _,
            buyer_required: _,
            seller_required: _,
            buyer_coin,
            seller_coin,
            buyer_deposited: _,
            seller_deposited: _,
            status: _,
            note: _,
        } = escrow;

        let mut buyer_coin = option::destroy_some(buyer_coin);
        let seller_coin = option::destroy_some(seller_coin);

        coin::join(&mut buyer_coin, seller_coin);

        transfer::public_transfer(buyer_coin, buyer);

        object::delete(id);
    }

    // Creator can cancel only if nobody deposited yet.
    public fun cancel_unfunded(
        escrow: Escrow,
        ctx: &TxContext
    ) {
        assert!(tx_context::sender(ctx) == escrow.creator, E_UNAUTHORIZED);
        assert!(escrow.status == STATUS_CREATED, E_INVALID_STATUS);
        assert!(!escrow.buyer_deposited, E_INVALID_STATUS);
        assert!(!escrow.seller_deposited, E_INVALID_STATUS);

        let Escrow {
            id,
            creator: _,
            buyer: _,
            seller: _,
            price: _,
            buyer_bond: _,
            seller_bond: _,
            buyer_required: _,
            seller_required: _,
            buyer_coin,
            seller_coin,
            buyer_deposited: _,
            seller_deposited: _,
            status: _,
            note: _,
        } = escrow;

        option::destroy_none(buyer_coin);
        option::destroy_none(seller_coin);

        object::delete(id);
    }
}