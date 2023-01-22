module hopeversegenesispet::HopeveresGenesisPet {

    use erc721::erc721::{Self,ItemBox,Collection,CollectionCapability};
    use sui::tx_context::{TxContext};
    use std::option;

    struct HOPEVERESGENESISPET has drop {}

    fun init(witness: HOPEVERESGENESISPET, ctx: &mut TxContext) {
       erc721::create_collection<HOPEVERESGENESISPET>(witness, b"HOPEVERESGENESISPET", b"", b"",2500, option::none(), ctx);
    }
    public entry fun mint(_gm:& CollectionCapability<HOPEVERESGENESISPET>,collection : &mut Collection<HOPEVERESGENESISPET>,box :&mut ItemBox<HOPEVERESGENESISPET>,amount : u64, ctx: &mut TxContext){       
        erc721::mint(_gm,collection,box,amount,ctx);
    }
    public entry fun mint_new(_gm:& CollectionCapability<HOPEVERESGENESISPET>,collection : &mut Collection<HOPEVERESGENESISPET>,amount : u64, ctx: &mut TxContext){       
        erc721::mint_new(_gm,collection,amount,ctx);
    }
    public entry fun burn(collection : &mut Collection<HOPEVERESGENESISPET>,box :&mut ItemBox<HOPEVERESGENESISPET>,token_id : u64){       
        erc721::burn(collection,box,token_id);
    }
    public entry fun change_owner(gm : CollectionCapability<HOPEVERESGENESISPET>, new_owner: address, ctx: &mut TxContext){        
        erc721::change_owner(gm,new_owner,ctx);
    }
}