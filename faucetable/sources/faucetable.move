//Extend functional of coin to generate faucet.
module faucetable::FaucetableToken {

    use sui::object::{Self,UID};
    use sui::coin::{Self,TreasuryCap,Coin};
    use sui::transfer;
    use sui::pay;
    use sui::tx_context::{Self, TxContext};

    const EFaucetSupplyOverflow : u64 = 1;

    const EZeroFaucetRefill : u64 = 2;
    const EOutofFaucet : u64 = 2;

    struct FaucetObject<phantom T> has key, store {
        id: UID,
        available : Coin<T>,
        per_request : u64
    }
    public entry fun create_faucetable<T: drop>(cap :&mut TreasuryCap<T>, faucet_supply : u64 , faucet_per_request : u64,ctx :&mut TxContext) {
        let minted_coin = coin::mint<T>(cap,faucet_supply,ctx);
        let faucet = FaucetObject<T> {
            id: object::new(ctx),
            available: minted_coin,
            per_request : faucet_per_request,
        };
        transfer::share_object(faucet);
    }
    public entry fun refill_faucet<T: drop>(cap :&mut TreasuryCap<T>,faucet : &mut FaucetObject<T>,refill_amount : u64,ctx :&mut TxContext) {
        assert!((coin::value(&faucet.available) + refill_amount) < 18446744073709551615u64,EFaucetSupplyOverflow);
        assert!(refill_amount > 0,EZeroFaucetRefill);
        let minted_coin = coin::mint(cap,refill_amount,ctx);
        coin::join(&mut faucet.available,minted_coin);
    }
    public entry fun request_faucet<T:drop>(faucet : &mut FaucetObject<T>,ctx :&mut TxContext){
        assert!(coin::value(&faucet.available) >= faucet.per_request,EOutofFaucet);
        pay::split_and_transfer(&mut faucet.available,faucet.per_request,tx_context::sender(ctx),ctx);
    }
    public entry fun update_per_request<T:drop>(_cap :&mut TreasuryCap<T>,faucet : &mut FaucetObject<T>,per_request:u64){
        faucet.per_request = per_request
    }
}