
//extension of erc1155::collection but support craftable operation.
module multitoken_craft::erc1155_craftable {

    use erc1155::collection::{MultiToken,Collection};
    use multitoken_craft::erc1155_craft_system::{Self,CraftCollection};
    use sui::tx_context::{TxContext};
    use sui::coin::{Coin};

    public entry fun craft<T:drop,Currency>(collection : &mut Collection<T>,forgecol : &CraftCollection<Currency>,template_id : u64,album :&mut MultiToken<T>,coin : &mut Coin<Currency>,apply_count : u64,ctx: &mut TxContext){
        erc1155_craft_system::craft(collection,forgecol,template_id,album,coin,apply_count,ctx);
    }
}