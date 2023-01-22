
module erc721_mint::erc721_whitelistable {

    use erc721::erc721::{Self,ItemBox,Collection};
    use erc721_mint::erc721_whitelist::{Self,WhitelistInfo};
    use sui::tx_context::{TxContext};
    use sui::coin::{Coin};
    const EItemUndefine: u64 = 4;

    public entry fun whitelist_mint<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut WhitelistInfo<Currency>,box : &mut ItemBox<T>, amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        erc721_whitelist::consume_mint_quota(collection,whitelist,amount,coin,ctx);
        erc721::mint_to_box(collection,box,amount,ctx);
    }
    public entry fun whitelist_mint_new<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut WhitelistInfo<Currency>, amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        erc721_whitelist::consume_mint_quota(collection,whitelist,amount,coin,ctx);
        erc721::mint_to_new_box(collection,amount,ctx);
    }
}