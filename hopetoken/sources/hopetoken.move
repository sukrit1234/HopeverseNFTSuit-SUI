
//Because of successful to decouple whitelist minting and crafting so no need to extends sui::coin functional
// just use manything easier than thinks.
module hopetoken::HopeToken {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct HOPETOKEN has drop {}

    fun init(witness: HOPETOKEN, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"HOPE", b"", b"", option::none(), ctx);
        transfer::share_object(metadata);
        transfer::transfer(treasury, tx_context::sender(ctx))
    }
}