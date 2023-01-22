/// This module provides handy functionality for wallets and `sui::Coin` management.
module erc1155::pay {
    use sui::tx_context::{Self, TxContext};
    use erc1155::collection::{Self,MultiToken};
    use sui::transfer;
    use std::vector;

    /// For when empty vector is supplied into join function.
    const ENoCoins: u64 = 0;

    /// Transfer `c` to the sender of the current transaction
    public fun keep<T>(a: MultiToken<T>, ctx: &TxContext) {
        transfer::transfer(a, tx_context::sender(ctx))
    }

    /// Split coin `self` to two MultiToken, one with Map<`splite_token_id` ,`split_amount`>,
    /// and the remaining balance is left is `self`.
    public entry fun split<T>(self: &mut MultiToken<T>,split_token_id : u64, split_amount: u64, ctx: &mut TxContext) {
        keep(collection::split(self,split_token_id, split_amount, ctx), ctx)
    }

    public entry fun split_multi<T>(self: &mut MultiToken<T>,split_token_ids : vector<u64>, split_amounts: vector<u64>, ctx: &mut TxContext) {
        keep(collection::split_multi(self,split_token_ids, split_amounts, ctx), ctx)
    }
    
    //like split but transfer to recipient instead of signer.
    public entry fun split_and_transfer<T>(c: &mut MultiToken<T>, token_id : u64 , amount: u64, recipient: address, ctx: &mut TxContext) {
        transfer::transfer(collection::split(c,token_id, amount, ctx), recipient)
    }


    /// Divide coin `self` into `n - 1` coins with equal balances. If the balance is
    /// not evenly divisible by `n`, the remainder is left in `self`.
    public entry fun divide_and_keep<T>(self: &mut MultiToken<T>, n: u64, ctx: &mut TxContext) {
        let vec: vector<MultiToken<T>> = collection::divide_into_n(self, n, ctx);
        let (i, len) = (0, vector::length(&vec));
        while (i < len) {
            transfer::transfer(vector::pop_back(&mut vec), tx_context::sender(ctx));
            i = i + 1;
        };
        vector::destroy_empty(vec);
    }

    /// Join `coin` into `self`. Re-exports `coin::join` function.
    public entry fun join<T>(self: &mut MultiToken<T>, multitoken: MultiToken<T>) {
        collection::join(self, multitoken)
    }

    /// Join everything in `coins` with `self`
    public entry fun join_vec<T>(self: &mut MultiToken<T>, multitokens: vector<MultiToken<T>>) {
        let (i, len) = (0, vector::length(&multitokens));
        while (i < len) {
            let multitoken = vector::pop_back(&mut multitokens);
            collection::join(self, multitoken);
            i = i + 1
        };
        // safe because we've drained the vector
        vector::destroy_empty(multitokens)
    }

    /// Join a vector of `Coin` into a single object and transfer it to `receiver`.
    public entry fun join_vec_and_transfer<T>(multitokens: vector<MultiToken<T>>, receiver: address) {
        assert!(vector::length(&multitokens) > 0, ENoCoins);
        let self = vector::pop_back(&mut multitokens);
        join_vec(&mut self, multitokens);
        transfer::transfer(self, receiver)
    }
}