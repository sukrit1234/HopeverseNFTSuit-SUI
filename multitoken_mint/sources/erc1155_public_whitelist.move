
//Public whiltelist is very simplify from normal whitelist.
//just keep remain to mint per wallet.
module multitoken_mint::erc1155_pulic_whitelist {

    use std::string;
    use sui::address;
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self,TxContext};
    use sui::vec_map::{Self,VecMap};
    use std::vector;
    use erc1155::collection::{Self,CollectionCapability,Collection};

    /// For when a type passed to create_supply is not a one-time witness.
    const EBadWitness: u64 = 0;

    /// For when invalid arguments are passed to a function.
    const EInvalidArg: u64 = 1;

    /// For when trying to split a coin more times than its balance allows.
    const ENotEnough: u64 = 2;

    const ENotContractOwner: u64 = 3;

    const EWhiteListUndefine: u64 = 4;

    const EParameterDimensionMismatch: u64 = 5;

    const EMintQuotaAlreadyDefined: u64 = 6;

    const EMintQuotaUndefined: u64 = 7;
    
    const EQuotaOverflow: u64 = 8;
    
    const ENotWhitelisted: u64 = 9;

    const ETokenUndefined: u64 = 10;

    const EInsufficientMintCost: u64 = 11;

    const ESameMerchantAddress: u64 = 12;

    struct PublicWhitelistInfo<phantom Currency> has key, store {
        id: UID,
        collection_id : ID,
        name: string::String,
        description : string::String, 
        individual_cap : u64,
        token_remains : VecMap<u64,u64>,
        token_quotas  : VecMap<u64,u64>,
        wallet_remains : VecMap<address,u64>,
        
        token_mint_prices : VecMap<u64,u64>,
        merchant_address : address
    }
    struct WhitelistDefined has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct WhitelistRemoved has copy, drop {
        id : ID,
        collection_id : ID
    }

    public entry fun define_whitelist_object<T:drop,Currency>(gm : &CollectionCapability<T>, name: vector<u8>, description: vector<u8>,ctx: &mut TxContext){
        
        let collection_id = collection::get_collection_id_from_owner(gm);
        let wlobj = PublicWhitelistInfo<Currency> {
            id: object::new(ctx), 
            collection_id : collection_id, 
            name: string::utf8(name),
            description : string::utf8(description),
            individual_cap : 1,
            token_remains : vec_map::empty<u64,u64>(),
            token_quotas : vec_map::empty<u64,u64>(),
            wallet_remains : vec_map::empty<address,u64>(),
            token_mint_prices : vec_map::empty<u64,u64>(),
            merchant_address : tx_context::sender(ctx)
        };

        let wl_id = object::uid_to_inner(&wlobj.id);
        transfer::share_object(wlobj);
        event::emit(WhitelistDefined {id : wl_id,collection_id : collection_id});
    }
    //Remove whitelist shared objet (in not real remove just cut reference make it invalid)
    public entry fun unuse_whitelist_object<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist :&mut PublicWhitelistInfo<Currency>){
       
        let collection_id = collection::get_collection_id_from_owner(gm);
        assert!(collection_id == whitelist.collection_id,EWhiteListUndefine);
       
        let wl_id = object::uid_to_inner(&whitelist.id);
        event::emit(WhitelistRemoved {id : wl_id,collection_id});
        whitelist.collection_id = object::id_from_address(address::from_u256(0));
    }
    public entry fun update_merchant<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist :&mut PublicWhitelistInfo<Currency>, new_merchant_address: address){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        assert!(whitelist.merchant_address != new_merchant_address,ESameMerchantAddress);
        whitelist.merchant_address = new_merchant_address;
    }
    public entry fun update_whitelist_name<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist :&mut PublicWhitelistInfo<Currency>, name: vector<u8>){
       
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.name = string::utf8(name);
    }
    public entry fun update_whitelist_description<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist :&mut PublicWhitelistInfo<Currency>, description: vector<u8>){
       
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.description = string::utf8(description);
    }

    public entry fun fill_token_for_mint<T : drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64,amount : u64,price : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        fill_token_for_mint_internal(whitelist,token_id,amount,price);
    }
    
    public entry fun remove_token_from_mint<T:drop,Currency:drop>(gm : &mut CollectionCapability<T>,whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64,){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        remove_token_from_mint_internal(whitelist,token_id);
    }
    
    public entry fun remove_token_from_mint_batch<T:drop,Currency:drop>(gm : &mut CollectionCapability<T>,whitelist : &mut PublicWhitelistInfo<Currency>,token_ids : vector<u64>){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        let num_id = vector::length(&token_ids);
        let i = 0;
        while (i < num_id) {
            let token_id = vector::borrow<u64>(&token_ids,i);
            remove_token_from_mint_internal(whitelist,*token_id);
            i = i + 1;
        };
    }

    public entry fun set_individual_cap<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut PublicWhitelistInfo<Currency>,individual_cap : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.individual_cap = individual_cap;

        let i = 0;
        let n = vec_map::size(&whitelist.wallet_remains);
        while (i < n) {
            let (_token_id , wallet_remain) = vec_map::get_entry_by_idx_mut<address,u64>(&mut whitelist.wallet_remains,i);
            if(individual_cap < (*wallet_remain))
                (*wallet_remain) = individual_cap;
            i = i + 1;
        };
    }

    fun consume_mint_fee<Currency>(whitelist : &PublicWhitelistInfo<Currency>,token_id : u64,amount : u64,coin :&mut Coin<Currency>,ctx: &mut TxContext){
        
       let mint_price_value = vec_map::get(&whitelist.token_mint_prices,&token_id);
       let remain_coin_value = coin::value(coin);

       let total_mint_fee_value = (*mint_price_value)*amount;
       assert!(remain_coin_value >= total_mint_fee_value,EInsufficientMintCost);
       if(total_mint_fee_value > 0){
           let mint_fee_coin = coin::split(coin,total_mint_fee_value,ctx);
           transfer::transfer(mint_fee_coin,whitelist.merchant_address);
       }
    }
    public fun consume_mint_quota<T:drop,Currency>(collection : &Collection<T>,whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64,amount : u64,coin :&mut Coin<Currency> ,ctx: &mut TxContext){
        assert!(match_with_collection(collection,whitelist),EWhiteListUndefine);

        let sender_address = tx_context::sender(ctx);
        assert!(vec_map::contains(&whitelist.token_remains,&token_id),ETokenUndefined);
        if(!vec_map::contains(&whitelist.wallet_remains,&sender_address)){
            vec_map::insert(&mut whitelist.wallet_remains,sender_address,whitelist.individual_cap);
        };

        let remain_for_sender = vec_map::get_mut(&mut whitelist.wallet_remains,&sender_address);
        assert!((*remain_for_sender) >= amount,EQuotaOverflow);
        
        let remain_for_token = vec_map::get_mut(&mut whitelist.token_remains,&token_id);
        assert!((*remain_for_token) >= amount,EQuotaOverflow);

        (*remain_for_sender) = (*remain_for_sender) - amount;
        (*remain_for_token) = (*remain_for_token) - amount;
        consume_mint_fee(whitelist,token_id,amount,coin,ctx);
    }
    public fun match_with_collection<T:drop,Currency>(collection : &Collection<T>,whitelist : &PublicWhitelistInfo<Currency>) : bool {
       
        let collection_id = collection::collection_id(collection);
         whitelist.collection_id == collection_id
    }
    public fun is_valid_whitelist<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &PublicWhitelistInfo<Currency>) : bool {   
        let collection_id = collection::get_collection_id_from_owner(gm);
        whitelist.collection_id == collection_id
    }


    public fun get_whitelist_id<Currency>(whitelist : &PublicWhitelistInfo<Currency>): ID{
        object::uid_to_inner(&whitelist.id)
    }
    public fun get_collection_id<Currency>(whitelist : &PublicWhitelistInfo<Currency>): ID{
        whitelist.collection_id
    }
    public fun get_name<Currency>(whitelist : &PublicWhitelistInfo<Currency>) : &string::String {
        &whitelist.name
    }
    public fun get_description<Currency>(whitelist : &PublicWhitelistInfo<Currency>) : &string::String {
        &whitelist.description
    }
    public fun get_wallet_mint_remain<Currency>(whitelist : &PublicWhitelistInfo<Currency>,addr : address) : u64 {
        if(vec_map::contains(&whitelist.wallet_remains,&addr)) {*(vec_map::get(&whitelist.wallet_remains,&addr))} else{0}
    }
    public fun get_token_remain<Currency>(whitelist : &PublicWhitelistInfo<Currency>,token_id : u64) : u64 {
        if(vec_map::contains<u64,u64>(&whitelist.token_remains,&token_id)){
            return (*vec_map::get(&whitelist.token_remains,&token_id))
        };
        return 0
    }
    
    ////////////////////////////////////////////////
    //Internal functions
    ////////////////////////////////////////////////

    fun fill_token_for_mint_internal<Currency>(whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64,amount : u64,price:u64){
        if(vec_map::contains(&whitelist.token_quotas,&token_id)){
           let remain = vec_map::get_mut(&mut whitelist.token_remains,&token_id);
           (*remain) = amount;

           let quotas = vec_map::get_mut(&mut whitelist.token_quotas,&token_id);
           (*quotas) = amount;

           let prices = vec_map::get_mut(&mut whitelist.token_mint_prices,&token_id);
           (*prices) = price;
        }
        else{
            vec_map::insert(&mut whitelist.token_quotas,token_id,amount);
            vec_map::insert(&mut whitelist.token_remains,token_id,amount);
            vec_map::insert(&mut whitelist.token_mint_prices,token_id,price);
        };
    }
    fun remove_token_from_mint_internal<Currency:drop>(whitelist : &mut PublicWhitelistInfo<Currency>,token_id : u64){
        assert!(vec_map::contains(&whitelist.token_quotas,&token_id),EMintQuotaUndefined);
        vec_map::remove(&mut whitelist.token_quotas,&token_id);
        vec_map::remove(&mut whitelist.token_remains,&token_id);  
        vec_map::remove(&mut whitelist.token_mint_prices,&token_id); 
    }   
}