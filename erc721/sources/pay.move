
module erc721::pay {
    use sui::tx_context::{Self, TxContext};
    use erc721::erc721::{Self,ItemBox};
    use sui::transfer;
    use std::vector;

    /// For when empty vector is supplied into join function.
    const ENoBox: u64 = 0;

    /// Transfer `c` to the sender of the current transaction
    public fun keep<T>(a: ItemBox<T>, ctx: &TxContext) {
        transfer::transfer(a, tx_context::sender(ctx))
    }

    /// Split coin `self` to two MultiToken, one with Map<`splite_token_id` ,`split_amount`>,
    /// and the remaining balance is left is `self`.
    public entry fun split<T>(self: &mut ItemBox<T>,split_token_id : u64, ctx: &mut TxContext) {
        keep(erc721::split(self,split_token_id, ctx), ctx)
    }

    public entry fun split_multi<T>(self: &mut ItemBox<T>,split_token_ids : vector<u64>, ctx: &mut TxContext) {
        keep(erc721::split_multi(self,split_token_ids, ctx), ctx)
    }
    
    //like split but transfer to recipient instead of signer.
    public entry fun split_and_transfer<T>(c: &mut ItemBox<T>, token_id : u64, recipient: address, ctx: &mut TxContext) {
        transfer::transfer(erc721::split(c,token_id, ctx), recipient)
    }

    /// Join `coin` into `self`. Re-exports `coin::join` function.
    public entry fun join<T>(self: &mut ItemBox<T>, box: ItemBox<T>) {
        erc721::join(self, box)
    }

    /// Join everything in `coins` with `self`
    public entry fun join_vec<T>(self: &mut ItemBox<T>, boxes: vector<ItemBox<T>>) {
        let (i, len) = (0, vector::length(&boxes));
        while (i < len) {
            let box = vector::pop_back(&mut boxes);
            erc721::join(self, box);
            i = i + 1
        };
        // safe because we've drained the vector
        vector::destroy_empty(boxes)
    }

    /// Join a vector of `Coin` into a single object and transfer it to `receiver`.
    public entry fun join_vec_and_transfer<T>(boxes: vector<ItemBox<T>>, receiver: address) {
        assert!(vector::length(&boxes) > 0, ENoBox);
        let self = vector::pop_back(&mut boxes);
        join_vec(&mut self, boxes);
        transfer::transfer(self, receiver)
    }
}
