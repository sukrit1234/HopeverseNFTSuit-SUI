//This is whitelist system for support all of erc1155.move nft
module multitoken_mint::erc1155_whitelist {

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

    const EInsufficientMintCost:u64 = 11;

    const ESameMerchantAddress : u64 = 12;

    struct WhitelistInfo<phantom Currency> has key, store {
        id: UID,
        collection_id : ID,
        name: string::String,
        description : string::String,
        quotas : VecMap<u64,MintItemQuota>,
        wallet_remains : VecMap<address,u64>,
        token_mint_prices : VecMap<u64,u64>,
        merchant_address : address
    }
    struct MintItemQuota has store,drop {
        total_quota : u64,
        per_wallet_quota : u64,
        remain : u64,
        per_wallet_remains : VecMap<address,u64> // Per wallet quota.
    }
    struct WhitelistDefined has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct WhitelistRemoved has copy, drop {
        id : ID,
        collection_id : ID
    }

    public entry fun define_whitelist_object<T:drop,Currency:drop>(gm : &CollectionCapability<T>, name: vector<u8>, description: vector<u8>,ctx: &mut TxContext){
        
        let collection_id = collection::get_collection_id_from_owner(gm);
        let wlobj = WhitelistInfo<Currency> {
            id: object::new(ctx), 
            collection_id : collection_id, 
            name: string::utf8(name),
            description : string::utf8(description),
            quotas : vec_map::empty<u64,MintItemQuota>(),
            wallet_remains : vec_map::empty<address,u64>(),
            token_mint_prices : vec_map::empty<u64,u64>(),
            merchant_address : tx_context::sender(ctx)
        };

        let wl_id = object::uid_to_inner(&wlobj.id);
        transfer::share_object(wlobj);
        event::emit(WhitelistDefined {id : wl_id,collection_id : collection_id});
    }
    //Remove WL from active WL , Please remember if you unuse use will never reuse again, must be create new one.
    public entry fun unuse_whitelist_object<T:drop,Currency:drop>(gm : &CollectionCapability<T>,whitelist :&mut WhitelistInfo<Currency>){
       
        let collection_id = collection::get_collection_id_from_owner(gm);
        assert!(collection_id == whitelist.collection_id,EWhiteListUndefine);
       
        let wl_id = object::uid_to_inner(&whitelist.id);
        event::emit(WhitelistRemoved {id : wl_id,collection_id});
        whitelist.collection_id = object::id_from_address(address::from_u256(0));
    }

    public entry fun update_whitelist_name<T:drop,Currency:drop>(gm : &CollectionCapability<T>,whitelist :&mut WhitelistInfo<Currency>, name: vector<u8>){
       
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.name =  string::utf8(name);
    }
    public entry fun update_whitelist_description<T:drop,Currency:drop>(gm : &CollectionCapability<T>,whitelist :&mut WhitelistInfo<Currency>, description: vector<u8>){
       
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.description = string::utf8(description);
    }
     public entry fun update_merchant<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist :&mut WhitelistInfo<Currency>, new_merchant_address: address){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        assert!(whitelist.merchant_address != new_merchant_address,ESameMerchantAddress);
        whitelist.merchant_address = new_merchant_address;
    }

    public entry fun update_whitelist_address<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency> , addr:address,per_wallet_quota:u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_whitelist_address_internal(whitelist,addr,per_wallet_quota);
    }
    public entry fun update_whitelist_addresse_batch<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency> , addresses:vector<address>,per_wallet_quota : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        let i = 0;
        let n = vector::length<address>(&addresses);
        while (i < n) {
            let addr = vector::borrow(&addresses,i);
            update_whitelist_address_internal(whitelist,*addr,per_wallet_quota);
            i = i + 1;
        };
    }
    public entry fun define_mint_quota<T:drop,Currency:drop>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64,per_wallet_quota : u64,price_per_token : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        define_mint_quota_internal(whitelist,token_id,total_quota,per_wallet_quota,price_per_token);
    }
    public entry fun remove_mint_quota<T:drop,Currency:drop>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        remove_mint_quota_internal(whitelist,token_id);
    }
    public entry fun remove_mint_quota_batch<T:drop,Currency:drop>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_ids : vector<u64>){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        let num_id = vector::length(&token_ids);
        let i = 0;
        while (i < num_id) {
            let token_id = vector::borrow<u64>(&token_ids,i);
            remove_mint_quota_internal(whitelist,*token_id);
            i = i + 1;
        };
    }
    public entry fun update_total_mint_quota<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_total_mint_quota_internal(whitelist,token_id,total_quota);
    }
    public entry fun update_remain_mint_quota<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,remain : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_remain_mint_quota_internal(whitelist,token_id,remain);
    }
    public entry fun update_mint_quota<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64,remain : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_mint_quota_internal(whitelist,token_id,total_quota,remain);
    }

    public entry fun update_mint_price<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,price_per_token : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_mint_price_internal(whitelist,token_id,price_per_token);
    }

    fun consume_mint_fee<Currency>(whitelist : &WhitelistInfo<Currency>,token_id : u64,amount : u64,coin :&mut Coin<Currency>,ctx: &mut TxContext){
        
       let mint_price_value = vec_map::get(&whitelist.token_mint_prices,&token_id);
       let remain_coin_value = coin::value(coin);

       let total_mint_fee_value = (*mint_price_value)*amount;
       assert!(remain_coin_value >= total_mint_fee_value,EInsufficientMintCost);
       if(total_mint_fee_value > 0){
           let mint_fee_coin = coin::split(coin,total_mint_fee_value,ctx);
           transfer::transfer(mint_fee_coin,whitelist.merchant_address);
       }
    }

    public fun consume_mint_quota<T:drop,Currency>(collection : &Collection<T>,whitelist : &mut WhitelistInfo<Currency>,token_id : u64,amount : u64,coin :&mut Coin<Currency>,ctx: &mut TxContext){
        assert!(match_with_collection(collection,whitelist),EWhiteListUndefine);

        let sender_address = tx_context::sender(ctx);
        assert!(vec_map::contains(&whitelist.wallet_remains,&sender_address),ENotWhitelisted);
        assert!(vec_map::contains(&whitelist.quotas,&token_id),ETokenUndefined);
        
        let remain_for_sender = vec_map::get_mut(&mut whitelist.wallet_remains,&sender_address);
        assert!((*remain_for_sender) >= amount,EQuotaOverflow);
        let quota = vec_map::get_mut(&mut whitelist.quotas,&token_id);
        assert!(vec_map::contains(&quota.per_wallet_remains,&sender_address),ENotWhitelisted);

        let remain_for_sender_in_token = vec_map::get_mut(&mut quota.per_wallet_remains,&sender_address);
        assert!((*remain_for_sender_in_token) >= amount,EQuotaOverflow);
        assert!(quota.remain >= amount,EQuotaOverflow);

        (*remain_for_sender) = (*remain_for_sender) - amount;
        (*remain_for_sender_in_token) = (*remain_for_sender_in_token) - amount;
        quota.remain = quota.remain - amount;
       
        consume_mint_fee(whitelist,token_id,amount,coin,ctx);
    }
    //Whitelist object getter functions.
    public fun is_valid_whitelist<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &WhitelistInfo<Currency>) : bool {
       
        let collection_id = collection::get_collection_id_from_owner(gm);
        whitelist.collection_id == collection_id
    }
    public fun match_with_collection<T:drop,Currency>(collection : &Collection<T>,whitelist : &WhitelistInfo<Currency>) : bool {
       
        let collection_id = collection::collection_id(collection);
        whitelist.collection_id == collection_id
    }


    public fun get_whitelist_id<Currency>(whitelist : &WhitelistInfo<Currency>): ID{
        object::uid_to_inner(&whitelist.id)
    }
    public fun get_collection_id<Currency>(whitelist : &WhitelistInfo<Currency>): ID{
        whitelist.collection_id
    }
    public fun get_name<Currency>(whitelist : &WhitelistInfo<Currency>) : &string::String {
        &whitelist.name
    }
    public fun get_description<Currency>(whitelist : &WhitelistInfo<Currency>) : &string::String {
        &whitelist.description
    }
    public fun get_wallet_mint_remain<Currency>(whitelist : &WhitelistInfo<Currency>,addr : address) : u64 {
        if(vec_map::contains(&whitelist.wallet_remains,&addr)) {*(vec_map::get(&whitelist.wallet_remains,&addr))} else{0}
    }
    public fun is_whitelisted<Currency>(whitelist : &WhitelistInfo<Currency>,addr : address) : bool {
        vec_map::contains(&whitelist.wallet_remains,&addr)
    }
    public fun get_total_quota<Currency>(whitelist : &WhitelistInfo<Currency>,token_id : u64) : u64 {
        if(vec_map::contains<u64,MintItemQuota>(&whitelist.quotas,&token_id)){
            let quota = vec_map::get(&whitelist.quotas,&token_id);
            return quota.total_quota
        };
        return 0
    }
    public fun get_per_wallet_quota<Currency>(whitelist : &WhitelistInfo<Currency>,token_id : u64) : u64 {
        if(vec_map::contains<u64,MintItemQuota>(&whitelist.quotas,&token_id)){
            let quota = vec_map::get(&whitelist.quotas,&token_id);
            return quota.per_wallet_quota
        };
        return 0
    }
    public fun get_token_remain<Currency>(whitelist : &WhitelistInfo<Currency>,token_id : u64) : u64 {
        if(vec_map::contains<u64,MintItemQuota>(&whitelist.quotas,&token_id)){
            let quota = vec_map::get(&whitelist.quotas,&token_id);
            return quota.remain
        };
        return 0
    }
    public fun get_token_remain_for_address<Currency>(whitelist : &WhitelistInfo<Currency>,token_id : u64,addr : address) : u64 {
        if(vec_map::contains<u64,MintItemQuota>(&whitelist.quotas,&token_id)){
            let quota = vec_map::get(&whitelist.quotas,&token_id);
            if(vec_map::contains(&quota.per_wallet_remains,&addr)){
                return (*vec_map::get(&quota.per_wallet_remains,&addr))
            }
        };
        return 0
    }
    
    ////////////////////////////////////////////////
    //Internal functions
    ////////////////////////////////////////////////

    fun define_mint_quota_internal<Currency:drop>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64,per_wallet_quota : u64,price_per_token : u64){
        assert!(!vec_map::contains(&whitelist.quotas,&token_id),EWhiteListUndefine);
        let quota = MintItemQuota{
            total_quota,per_wallet_quota,
            remain : total_quota,
            per_wallet_remains : vec_map::empty()
        };
        
        let i = 0;
        let n = vec_map::size(&whitelist.wallet_remains);
        while (i < n) {
            let (wl_addr,_remain) = vec_map::get_entry_by_idx(&whitelist.wallet_remains,i);
            vec_map::insert(&mut quota.per_wallet_remains,*wl_addr,per_wallet_quota);
            i = i + 1;
        };
        vec_map::insert(&mut whitelist.quotas,token_id,quota);
        vec_map::insert(&mut whitelist.token_mint_prices,token_id,price_per_token);
    }
    fun remove_mint_quota_internal<Currency:drop>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64){
        assert!(vec_map::contains(&whitelist.quotas,&token_id),EMintQuotaUndefined);
        vec_map::remove(&mut whitelist.quotas,&token_id);   
        vec_map::remove(&mut whitelist.token_mint_prices,&token_id);
    }
    
    fun update_mint_price_internal<Currency>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64,price_per_token : u64){
        assert!(vec_map::contains(&whitelist.token_mint_prices,&token_id),EMintQuotaUndefined);
        let prices = vec_map::get_mut(&mut whitelist.token_mint_prices,&token_id);
        (*prices) = price_per_token;
    }
    
    fun update_total_mint_quota_internal<Currency>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64){
        assert!(vec_map::contains(&whitelist.quotas,&token_id),EMintQuotaUndefined);
        let quota = vec_map::get_mut(&mut whitelist.quotas,&token_id);
        quota.total_quota = total_quota;
        if(total_quota < quota.remain){
            quota.remain = total_quota;
            clamp_per_wallet_remain_by_total_remain(quota);
        };
        if(total_quota < quota.per_wallet_quota){
            quota.per_wallet_quota = total_quota;
        };
    }
    fun update_remain_mint_quota_internal<Currency>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64,remain : u64){
        assert!(vec_map::contains(&whitelist.quotas,&token_id),EMintQuotaUndefined);
        let quota = vec_map::get_mut(&mut whitelist.quotas,&token_id);
        if(remain > quota.total_quota){quota.remain = quota.total_quota;}
        else{quota.remain = remain;};
        clamp_per_wallet_remain_by_total_remain(quota);
    }
    fun update_mint_quota_internal<Currency>(whitelist : &mut WhitelistInfo<Currency>,token_id : u64,total_quota : u64,remain : u64){
        assert!(remain <= total_quota,EQuotaOverflow);
        assert!(vec_map::contains(&whitelist.quotas,&token_id),EMintQuotaUndefined);
        let quota = vec_map::get_mut(&mut whitelist.quotas,&token_id);
        quota.total_quota = total_quota;

        if(remain > total_quota){quota.remain = total_quota}
        else{ quota.remain = remain;}; 

        if(total_quota < quota.per_wallet_quota){
            quota.per_wallet_quota = total_quota;
        };
        clamp_per_wallet_remain_by_total_remain(quota);
    }
    fun clamp_per_wallet_remain_by_total_remain(quota :&mut MintItemQuota){
        let i = 0;
        let n = vec_map::size(&quota.per_wallet_remains);
        while (i < n) {
            let (_token_id , wallet_remain) = vec_map::get_entry_by_idx_mut<address,u64>(&mut quota.per_wallet_remains,i);
            if(quota.remain < (*wallet_remain))
                (*wallet_remain) = quota.remain;
            i = i + 1;
        };
    }
    fun update_whitelist_address_internal<Currency>(whitelist : &mut WhitelistInfo<Currency> , addr : address,per_wallet_quota:u64){
        
        if(vec_map::contains(&whitelist.wallet_remains,&addr))
        {
           let wallet_remain = vec_map::get_mut(&mut whitelist.wallet_remains,&addr);
           *wallet_remain = per_wallet_quota;
        }
        else
            vec_map::insert(&mut whitelist.wallet_remains,addr,per_wallet_quota);
    

        let i = 0;
        let n = vec_map::size(&whitelist.quotas);
        while (i < n) {
            let (_token_id , quota) = vec_map::get_entry_by_idx_mut<u64,MintItemQuota>(&mut whitelist.quotas,i);
            if(!vec_map::contains(&quota.per_wallet_remains,&addr))
                vec_map::insert(&mut quota.per_wallet_remains,addr,quota.per_wallet_quota);
            i = i + 1;
        };
    }
    
}