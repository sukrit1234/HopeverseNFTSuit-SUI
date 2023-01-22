
//extension of erc1155::collection but support whitelisted mint.
module multitoken_mint::erc1155_whitelistable {

    use erc1155::collection::{Self,MultiToken,Collection};
    use multitoken_mint::erc1155_whitelist::{Self,WhitelistInfo};
    use multitoken_mint::erc1155_pulic_whitelist::{Self,PublicWhitelistInfo};
    use sui::tx_context::{TxContext};
    use sui::coin::{Coin};
    const EItemUndefine: u64 = 4;

    public entry fun whitelist_mint<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut WhitelistInfo<Currency>,album : &mut MultiToken<T>,token_id : u64 , amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        assert!(collection::is_definded(collection,token_id),EItemUndefine);
        erc1155_whitelist::consume_mint_quota(collection,whitelist,token_id,amount,coin,ctx);
        collection::mint_amount(collection,album,token_id,amount);
    }
    public entry fun whitelist_mint_new<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64 , amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        assert!(collection::is_definded(collection,token_id),EItemUndefine);
        erc1155_whitelist::consume_mint_quota(collection,whitelist,token_id,amount,coin,ctx);
        collection::mint_new_amount(collection,token_id,amount,ctx);
    }
    public entry fun public_mint<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut PublicWhitelistInfo<Currency>,album : &mut MultiToken<T>,token_id : u64 , amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        assert!(collection::is_definded(collection,token_id),EItemUndefine);
        erc1155_pulic_whitelist::consume_mint_quota(collection,whitelist,token_id,amount,coin,ctx);
        collection::mint_amount(collection,album,token_id,amount);
    }
    public entry fun public_mint_new<T:drop,Currency>(collection : &mut Collection<T>,whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64 , amount : u64,coin :&mut Coin<Currency>, ctx: &mut TxContext){
        assert!(collection::is_definded(collection,token_id),EItemUndefine);
        erc1155_pulic_whitelist::consume_mint_quota(collection,whitelist,token_id,amount,coin,ctx);
        collection::mint_new_amount(collection,token_id,amount,ctx);
    }
}