
//extension of erc1155::collection but support forging operation.
module multitoken_forge::erc1155_forgable {

    use erc1155::collection::{MultiToken,Collection};
    use multitoken_forge::erc1155_forge_system::{Self,ForgeCollection};
    use sui::tx_context::{TxContext};
    use sui::coin::{Coin};

    public entry fun forge<T:drop,Currency>(collection : &mut Collection<T>,forgecol : &ForgeCollection<Currency>,template_id : u64,album :&mut MultiToken<T>,coin : &mut Coin<Currency>,apply_count : u64,ctx: &mut TxContext){
        erc1155_forge_system::forge(collection,forgecol,template_id,album,coin,apply_count,ctx);
    }
}