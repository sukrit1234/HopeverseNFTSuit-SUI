//This is whitelist system for support all of erc1155.move nft
module erc721_mint::erc721_whitelist {

    use std::string;
    use sui::address;
    use sui::object::{Self,UID,ID};
    use sui::coin::{Self,Coin};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self,TxContext};
    use sui::vec_map::{Self,VecMap};
    use std::vector;
    use erc721::erc721::{Self,CollectionCapability,Collection};

    /// For when a type passed to create_supply is not a one-time witness.
    const EBadWitness: u64 = 0;

    /// For when invalid arguments are passed to a function.
    const EInvalidArg: u64 = 1;

    const EWhiteListUndefine: u64 = 4;

    const EMintQuotaUndefined: u64 = 7;
    
    const EQuotaOverflow: u64 = 8;
    
    const ENotWhitelisted: u64 = 9;

    const EInsufficientMintCost:u64 = 11;

    const ESameMerchantAddress : u64 = 12;

    struct WhitelistInfo<phantom Currency> has key, store {
        id: UID,
        collection_id : ID,
        as_public : bool,
        name: string::String,
        description : string::String,
        total_quota : u64,
        individual_cap : u64,
        total_remain : u64,
        token_mint_price : u64,
        wallet_remains : VecMap<address,u64>,
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

    fun define_whitelist_object_internal<T:drop,Currency:drop>(gm : &CollectionCapability<T>,as_public : bool, name: vector<u8>, description: vector<u8>,total_quota : u64 , individual_cap : u64 , mint_price : u64 ,ctx: &mut TxContext){
        let collection_id = erc721::get_collection_id_from_owner(gm);
        let wlobj = WhitelistInfo<Currency> {
            id: object::new(ctx), 
            collection_id : collection_id, 
            as_public : as_public,
            name: string::utf8(name),
            description : string::utf8(description),
            total_quota : total_quota,
            individual_cap : individual_cap,
            total_remain : total_quota,
            token_mint_price : mint_price,
            wallet_remains : vec_map::empty<address,u64>(),
            merchant_address : tx_context::sender(ctx)
        };

        let wl_id = object::uid_to_inner(&wlobj.id);
        transfer::share_object(wlobj);
        event::emit(WhitelistDefined {id : wl_id,collection_id : collection_id});
    }

    public entry fun define_whitelist_object<T:drop,Currency:drop>(gm : &CollectionCapability<T>, name: vector<u8>, description: vector<u8>,total_quota : u64 , individual_cap : u64 , mint_price : u64 ,ctx: &mut TxContext){
        define_whitelist_object_internal<T,Currency>(gm,false,name,description,total_quota,individual_cap,mint_price,ctx);
    }
    public entry fun define_whitelist_public_object<T:drop,Currency:drop>(gm : &CollectionCapability<T>, name: vector<u8>, description: vector<u8>,total_quota : u64 , individual_cap : u64 , mint_price : u64 ,ctx: &mut TxContext){
        define_whitelist_object_internal<T,Currency>(gm,true,name,description,total_quota,individual_cap,mint_price,ctx);
    }

    //Remove WL from active WL , Please remember if you unuse use will never reuse again, must be create new one.
    public entry fun unuse_whitelist_object<T:drop,Currency:drop>(gm : &CollectionCapability<T>,whitelist :&mut WhitelistInfo<Currency>){
       
        let collection_id = erc721::get_collection_id_from_owner(gm);
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

    public entry fun update_whitelist_address<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency> , addr:address){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        update_whitelist_address_internal(whitelist,addr);
    }
    public entry fun update_whitelist_addresse_batch<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency> , addresses:vector<address>){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        let i = 0;
        let n = vector::length<address>(&addresses);
        while (i < n) {
            let addr = vector::borrow(&addresses,i);
            update_whitelist_address_internal(whitelist,*addr);
            i = i + 1;
        };
    }
    public entry fun update_mint_price<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,price_per_token : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.token_mint_price = price_per_token;
    }
    public entry fun update_total_quota<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,total_quota : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.total_quota = total_quota;
        if(total_quota < whitelist.total_remain){
            whitelist.total_remain = total_quota;
            clamp_per_wallet_remain_by_total_remain(whitelist);
        };
        if(total_quota < whitelist.individual_cap){
            whitelist.individual_cap = total_quota;
        };
    }
    public entry fun update_total_remain<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,remain : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        if(remain > whitelist.total_quota){whitelist.total_remain = whitelist.total_quota;}
        else{whitelist.total_remain = remain;};
        clamp_per_wallet_remain_by_total_remain(whitelist);
    }
    public entry fun update_mint_quota_and_remain<T:drop,Currency>(gm : &mut CollectionCapability<T>,whitelist : &mut WhitelistInfo<Currency>,total_quota : u64,remain : u64){
        assert!(is_valid_whitelist(gm,whitelist),EWhiteListUndefine);
        whitelist.total_quota = total_quota;

        if(remain > total_quota){whitelist.total_remain = total_quota}
        else{ whitelist.total_remain = remain;}; 

        if(total_quota < whitelist.individual_cap){
            whitelist.individual_cap = total_quota;
        };
        clamp_per_wallet_remain_by_total_remain(whitelist);
    }
    fun clamp_per_wallet_remain_by_total_remain<Currency>(whitelist : &mut WhitelistInfo<Currency>){
        let i = 0;
        let n = vec_map::size(&whitelist.wallet_remains);
        while (i < n) {
            let (_addr , wallet_remain) = vec_map::get_entry_by_idx_mut<address,u64>(&mut whitelist.wallet_remains,i);
            if(whitelist.total_remain < (*wallet_remain))
                (*wallet_remain) = whitelist.total_remain;
            i = i + 1;
        };
    }
    fun update_whitelist_address_internal<Currency>(whitelist : &mut WhitelistInfo<Currency> , addr : address){
        
        if(vec_map::contains(&whitelist.wallet_remains,&addr))
        {
           let wallet_remain = vec_map::get_mut(&mut whitelist.wallet_remains,&addr);
           *wallet_remain = whitelist.individual_cap;
        }
        else
            vec_map::insert(&mut whitelist.wallet_remains,addr,whitelist.individual_cap);
    }
    fun consume_mint_fee<Currency>(whitelist : &WhitelistInfo<Currency>,amount : u64,coin :&mut Coin<Currency>,ctx: &mut TxContext){

       let remain_coin_value = coin::value(coin);
       let total_mint_fee_value = (whitelist.token_mint_price)*amount;
       assert!(remain_coin_value >= total_mint_fee_value,EInsufficientMintCost);
       if(total_mint_fee_value > 0){
           let mint_fee_coin = coin::split(coin,total_mint_fee_value,ctx);
           transfer::transfer(mint_fee_coin,whitelist.merchant_address);
       }
    }
    public fun consume_mint_quota<T:drop,Currency>(collection : &Collection<T>,whitelist : &mut WhitelistInfo<Currency>,amount : u64,coin :&mut Coin<Currency>,ctx: &mut TxContext){
        assert!(match_with_collection(collection,whitelist),EWhiteListUndefine);
        
        assert!(whitelist.total_remain >= amount,EQuotaOverflow);

        let sender_address = tx_context::sender(ctx);
        if(whitelist.as_public){
            //public whitelist allow everyone so if address does not register just register it.
            if(!vec_map::contains(&whitelist.wallet_remains,&sender_address)){
                vec_map::insert(&mut whitelist.wallet_remains,sender_address,whitelist.individual_cap);
            };
        }
        else{
            //If not public whitelist check , registeration , if not register rejected.
            assert!(vec_map::contains(&whitelist.wallet_remains,&sender_address),ENotWhitelisted);
        };
        
        let remain_for_sender = vec_map::get_mut(&mut whitelist.wallet_remains,&sender_address);
        assert!((*remain_for_sender) >= amount,EQuotaOverflow);

        (*remain_for_sender) = (*remain_for_sender) - amount;
        whitelist.total_remain = whitelist.total_remain - amount;
       
        consume_mint_fee(whitelist,amount,coin,ctx);
    }

    //Whitelist object getter functions.
    public fun is_valid_whitelist<T:drop,Currency>(gm : &CollectionCapability<T>,whitelist : &WhitelistInfo<Currency>) : bool {
       
        let collection_id = erc721::get_collection_id_from_owner(gm);
        whitelist.collection_id == collection_id
    }
    public fun match_with_collection<T:drop,Currency>(collection : &Collection<T>,whitelist : &WhitelistInfo<Currency>) : bool {
       
        let collection_id = erc721::collection_id(collection);
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
    public fun get_total_quota<Currency>(whitelist : &WhitelistInfo<Currency>) : u64 {
        whitelist.total_quota
    }
    public fun get_individual_cap<Currency>(whitelist : &WhitelistInfo<Currency>) : u64 {
         whitelist.individual_cap
    }
    public fun get_token_remain<Currency>(whitelist : &WhitelistInfo<Currency>) : u64 {
         whitelist.total_remain
    }
    public fun get_token_remain_for_address<Currency>(whitelist : &WhitelistInfo<Currency>,addr : address) : u64 {
        if(vec_map::contains(&whitelist.wallet_remains,&addr)){
            return *(vec_map::get(&whitelist.wallet_remains,&addr))
        };
        return 0
    }
}