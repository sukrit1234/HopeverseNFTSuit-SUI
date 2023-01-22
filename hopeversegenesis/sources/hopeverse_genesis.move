module hopeversegenesis::HopeveresGenesis {

    use erc1155::collection::{Self,MultiToken,Collection,CollectionCapability};
    use sui::tx_context::{TxContext};
    use std::option;

    struct HOPEVERESGENESIS has drop {}

    const EItemUndefine: u64 = 4;

    fun init(witness: HOPEVERESGENESIS, ctx: &mut TxContext) {
       collection::create_collection<HOPEVERESGENESIS>(witness, b"HOPEVERESGENESIS", b"", b"", option::none(), ctx);
    }
    public entry fun define_item(gm:&mut CollectionCapability<HOPEVERESGENESIS>,collection : &mut Collection<HOPEVERESGENESIS>, name: vector<u8>,token_uri: vector<u8>,max_supply : u64, ctx: &mut TxContext){
       collection::define_item(gm,collection,name,token_uri,max_supply,ctx);
    }

    public entry fun mint(_gm:& CollectionCapability<HOPEVERESGENESIS>,collection : &mut Collection<HOPEVERESGENESIS>,multitoken :&mut MultiToken<HOPEVERESGENESIS>,token_id : u64,amount : u64){       
        collection::mint(_gm,collection,multitoken,token_id,amount);
    }
    public entry fun mint_new(_gm:& CollectionCapability<HOPEVERESGENESIS>,collection : &mut Collection<HOPEVERESGENESIS>,token_id : u64,amount : u64, ctx: &mut TxContext){       
        collection::mint_new(_gm,collection,token_id,amount,ctx);
    }
    public entry fun burn(collection : &mut Collection<HOPEVERESGENESIS>,multitoken :&mut MultiToken<HOPEVERESGENESIS>,token_id : u64,amount : u64){       
        collection::burn(collection,multitoken,token_id,amount);
    }
    public entry fun change_owner(gm : CollectionCapability<HOPEVERESGENESIS>, new_owner: address, ctx: &mut TxContext){        
        collection::change_owner(gm,new_owner,ctx);
    }
}