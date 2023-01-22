module erc1155::collection {

    use std::string;
    use std::ascii;
    use std::option::{Self,Option};
    use sui::object::{Self,UID,ID};
    use sui::event;
    use sui::url::{Self,Url};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::vec_map::{Self,VecMap};
    use std::vector;
    use erc1155::balance::{Self,Supply , Balance};
    use erc1155::erc1155_metadata::{Self,ERC1155Metadata};

    /// For when a type passed to create_supply is not a one-time witness.
    const EBadWitness: u64 = 0;

    /// For when invalid arguments are passed to a function.
    const EInvalidArg: u64 = 1;

    /// For when trying to split a coin more times than its balance allows.
    const ENotEnough: u64 = 2;

    const ENotContractOwner: u64 = 3;

    const EItemUndefine: u64 = 4;

    const ENotWhitelisted: u64 = 5;

    const ENoTokenInBalance: u64 = 6;

    const EArgumentDimensionMismatch: u64 = 7;

    const EOverMaxSupply: u64 = 8;

    struct MultiToken<phantom T> has key, store {
        id: UID,
        balances: VecMap<u64,Balance<T>>
    }

    /// Each Coin type T created through `create_nft_collection` function will have a
    /// unique instance of CoinMetadata<T> that stores the metadata for this coin type.
    struct CollectionMetadata<phantom T> has key, store {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Symbol for the token
        symbol: ascii::String,
        /// Description of the token
        description: string::String,
        /// URL for the token logo
        icon_url: Option<Url>,

        capability_object_id : ID,
        collection_object_id : ID,
    }

    struct NFTDefinition<phantom T> has key, store {
        id: UID,
        metadata : ERC1155Metadata
    }

    /// Capability allowing the bearer to mint and burn
    /// coins of type `T`. Transferable
    struct CollectionCapability<phantom T> has key, store {
        id: UID,
        runing_no : u64, //Change to u256 if support.
        collection_object_id : ID
    }

    struct Collection<phantom T> has key, store {
        id: UID,
        items : VecMap<u64,NFTDefinition<T>>,
        token_supplies : VecMap<u64,Supply<T>>
    }


    /// Register the managed currency to acquire its `CollectionCapability`. Because
    /// this is a module initializer, it ensures the currency only gets
    /// registered once.
   
    struct CollectionCreated<phantom T> has copy, drop {
        metadata_id : ID,
        capability_object_id : ID,
        collection_object_id : ID,
    }
    struct ItemDefined<phantom T> has copy, drop {
        id : ID, 
        token_id : u64
    }

    public fun create_collection<T: drop>(witness: T,symbol: vector<u8>,name: vector<u8>,description: vector<u8>,icon_url: Option<Url>,ctx: &mut TxContext){
        // Make sure there's only one instance of the type T
        assert!(sui::types::is_one_time_witness(&witness), EBadWitness);

        let collection_object = Collection<T> {
            id: object::new(ctx),    
            items : vec_map::empty(),
            token_supplies : vec_map::empty<u64,Supply<T>>()
        };
        
        let collection_object_id = object::uid_to_inner(&collection_object.id);
        let capability_object = CollectionCapability<T> {
            id: object::new(ctx),    
            runing_no : 0,
            collection_object_id,
        };
        let capability_object_id = object::uid_to_inner(&capability_object.id);

        let collection_metadata = CollectionMetadata<T> {
            id: object::new(ctx),
            name: string::utf8(name),
            symbol: ascii::string(symbol),
            description: string::utf8(description),
            icon_url,capability_object_id,collection_object_id
        };
        
        let metadata_id = object::uid_to_inner(&collection_metadata.id);

        transfer::share_object(collection_object);
        transfer::share_object(collection_metadata);
        transfer::transfer(capability_object,tx_context::sender(ctx));

        // Emit Currency metadata as an event.
        event::emit(CollectionCreated<T> {metadata_id,capability_object_id,collection_object_id});
    }
    public fun define_item<T:drop>(gm:&mut CollectionCapability<T>,collection : &mut Collection<T>, name: vector<u8>,token_uri: vector<u8>,max_supply : u64, ctx: &mut TxContext){
       
        let next_id = gm.runing_no + 1;
        let definition = NFTDefinition{
            id : object::new(ctx),
            metadata : erc1155_metadata::new(erc1155_metadata::new_token_id(next_id), name,token_uri,max_supply)
        };
        
        let item_id = object::uid_to_inner(&definition.id);
        
        vec_map::insert(&mut collection.items,next_id,definition);
        vec_map::insert(&mut collection.token_supplies,next_id,balance::create_supply());

        gm.runing_no = next_id;
        event::emit(ItemDefined<T> {id : item_id,token_id : next_id});
    }

    public entry fun change_owner<T: drop>(gm : CollectionCapability<T>, new_owner: address, ctx: &mut TxContext){        
        let signer_addr = tx_context::sender(ctx);
        assert!(signer_addr != new_owner,ENotContractOwner);
        transfer::transfer(gm, new_owner);
    }
    public entry fun update_item_name<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,id : u64, name: vector<u8>, _ctx: &mut TxContext){

        assert!(vec_map::contains(&collection.items,&id) ,EItemUndefine);
        let item = vec_map::get_mut(&mut collection.items,&id);
        erc1155_metadata::update_name(&mut item.metadata,name);

    }
    public entry fun update_item_uri<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,id : u64,token_uri: vector<u8>, _ctx: &mut TxContext){
        
        assert!(vec_map::contains(&collection.items,&id) ,EItemUndefine);
        let item = vec_map::get_mut(&mut collection.items,&id);
        erc1155_metadata::update_token_uri(&mut item.metadata,token_uri);
    }
    public entry fun update_item_maxsupply<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,id : u64, max_supply : u64, _ctx: &mut TxContext){
        
        assert!(vec_map::contains(&collection.items,&id) ,EItemUndefine);
        let item = vec_map::get_mut(&mut collection.items,&id);
        erc1155_metadata::update_max_supply(&mut item.metadata,max_supply);
    }
    
    public entry fun mint<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,multitoken :&mut MultiToken<T>,token_id : u64,amount : u64){       
        assert!(is_definded(collection,token_id),EItemUndefine);
        mint_amount(collection,multitoken,token_id,amount);
    }
    public entry fun mint_new<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,token_id : u64,amount : u64, ctx: &mut TxContext){       
        assert!(is_definded(collection,token_id),EItemUndefine);
        mint_new_amount(collection,token_id,amount,ctx);
    }
    public entry fun burn<T:drop>(collection : &mut Collection<T>,multitoken :&mut MultiToken<T>,token_id : u64,amount : u64){       
        assert!(is_definded(collection,token_id),EItemUndefine);
        burn_amount(collection,multitoken,token_id,amount);
    }
    public fun is_definded<T:drop>(collection : &Collection<T>,token_id : u64) : bool {
        vec_map::contains(&collection.items,&token_id)
    }

    //Mint by create new multitoken and send to signer.
    public fun mint_new_amount<T:drop>(collection : &mut Collection<T>,token_id : u64,amount : u64, ctx: &mut TxContext){       
        
        let total_supply = vec_map::get_mut(&mut collection.token_supplies,&token_id);

        let definition = vec_map::get(&collection.items,&token_id);
        let max_supply = erc1155_metadata::get_max_supply(&definition.metadata);
        assert!((balance::supply_value(total_supply) + amount) <= max_supply,EOverMaxSupply);

        let topup_balance = balance::increase_supply(total_supply, amount);
        let album = MultiToken<T>{
            id : object::new(ctx),
            balances: vec_map::empty()
        };
        vec_map::insert(&mut album.balances,token_id,topup_balance);
        
        let sender_address = tx_context::sender(ctx);
        transfer::transfer(album,sender_address);
    }
    //Mint and topup in currently album.
    public fun mint_amount<T:drop>(collection : &mut Collection<T>,multitoken :&mut MultiToken<T>,token_id : u64,amount : u64){       
        
        let total_supply = vec_map::get_mut(&mut collection.token_supplies,&token_id);

        let definition = vec_map::get(&collection.items,&token_id);
        let max_supply = erc1155_metadata::get_max_supply(&definition.metadata);
        assert!((balance::supply_value(total_supply) + amount) <= max_supply,EOverMaxSupply);

        let topup_balance = balance::increase_supply(total_supply, amount);
        if(vec_map::contains(&multitoken.balances,&token_id)){
            let album_balance = vec_map::get_mut(&mut multitoken.balances,&token_id);
            balance::join(album_balance,topup_balance);
        }
        else{
            vec_map::insert(&mut multitoken.balances,token_id,topup_balance);
        }
    }
    public fun burn_amount<T:drop>(collection : &mut Collection<T>,multitoken :&mut MultiToken<T>,token_id : u64,amount : u64){       
        assert!(vec_map::contains(&multitoken.balances,&token_id),ENotEnough);
        let album_balance = vec_map::get_mut(&mut multitoken.balances,&token_id);
        
        assert!(balance::value(album_balance) >= amount,ENotEnough);
        let removed_balance = balance::split(album_balance,amount);

        let total_supply = vec_map::get_mut(&mut collection.token_supplies,&token_id);
        balance::decrease_supply(total_supply, removed_balance); 
    }
    

    //////////////////////////////////////////////
    // getter setter function
    //////////////////////////////////////////////
    public fun get_collection_id_from_owner<T:drop>(owner : &CollectionCapability<T>) : ID{
        owner.collection_object_id
    }
    public fun get_collection_name<T:drop>(metadata : &CollectionMetadata<T>) : string::String{
        metadata.name
    }
    public fun get_collection_symbol<T:drop>(metadata : &CollectionMetadata<T>) : ascii::String{
        metadata.symbol
    }
    public fun get_collection_description<T:drop>(metadata : &CollectionMetadata<T>) : string::String{
        metadata.description
    }
    public fun get_icon_url_description<T:drop>(metadata : &CollectionMetadata<T>) : Option<Url>{
        metadata.icon_url
    }
    public fun collection_id<T:drop>(collection : &Collection<T>) : ID{
        object::uid_to_inner(&collection.id)
    }
    public fun get_collection_id<T:drop>(metadata : &CollectionMetadata<T>) : ID{
        metadata.collection_object_id
    }
    public fun get_capability_id<T:drop>(metadata : &CollectionMetadata<T>) : ID{
        metadata.capability_object_id
    }
    public entry fun update_name<T:drop>(_colcap: &CollectionCapability<T>, metadata: &mut CollectionMetadata<T>, name: string::String){
        metadata.name = name;
    }
    public entry fun update_symbol<T:drop>(_colcap: &CollectionCapability<T>, metadata: &mut CollectionMetadata<T>, symbol: ascii::String) {
        metadata.symbol = symbol;
    }
    public entry fun update_description<T:drop>(_colcap: &CollectionCapability<T>, metadata: &mut CollectionMetadata<T>, description: string::String) {
        metadata.description = description;
    }
    public entry fun update_icon_url<T:drop>(_colcap: &CollectionCapability<T>, metadata: &mut CollectionMetadata<T>, url: ascii::String) {
        metadata.icon_url = option::some(url::new_unsafe(url));
    }

    ////////////////////////////////////////////////
    //Multitoken management methods.
    ////////////////////////////////////////////////

    /// Consume the Multitoken `a` and add its value to `self`.
    /// Aborts if one of token_id's value over U64MAX
    public fun join<T>(self: &mut MultiToken<T>, a: MultiToken<T>) {
        let MultiToken { id, balances } = a;
        object::delete(id);

        while(!vec_map::is_empty(&balances)){
            let (token_id,to_topup_balance) = vec_map::pop(&mut balances);
            if(vec_map::contains(&self.balances,&token_id)){
                let self_balance = vec_map::get_mut(&mut self.balances,&token_id);
                balance::join(self_balance,to_topup_balance);
            }
            else{
                vec_map::insert(&mut self.balances,token_id,to_topup_balance);
            };
        };
        vec_map::destroy_empty(balances);
    }
    public fun split<T>(self: &mut MultiToken<T>,split_token_id: u64, split_amount: u64, ctx: &mut TxContext): MultiToken<T> {
        assert!(vec_map::contains(&self.balances,&split_token_id),ENoTokenInBalance);
        let self_balance = vec_map::get_mut(&mut self.balances,&split_token_id);
        let splited_balance = balance::split(self_balance,split_amount);
        
        let new_one = MultiToken {
            id : object::new(ctx),
            balances : vec_map::empty()
        };
        vec_map::insert(&mut new_one.balances,split_token_id,splited_balance);
        
        (new_one)
    }
    public fun split_multi<T>(self: &mut MultiToken<T>,split_token_ids: vector<u64>, split_amounts: vector<u64>, ctx: &mut TxContext): MultiToken<T> {
        let num_ids = vector::length(&split_token_ids);
        assert!(num_ids == vector::length(&split_amounts),EArgumentDimensionMismatch);
        
        let i = 0;
        while(i < num_ids){
            let token_id = vector::borrow(&split_token_ids,i);
            assert!(vec_map::contains(&self.balances,token_id),ENoTokenInBalance);
            i = i + 1;
        };

        let new_one = MultiToken {
            id : object::new(ctx),
            balances : vec_map::empty()
        };

        let ii = 0;
        while(ii < num_ids){
            let token_id = vector::borrow(&split_token_ids,ii);
            let token_amount = vector::borrow(&split_amounts,ii);
            let self_balance = vec_map::get_mut(&mut self.balances,token_id);
            let splited_balance = balance::split(self_balance,*token_amount);
            vec_map::insert(&mut new_one.balances,*token_id,splited_balance);
            ii = ii + 1;
        };
        (new_one)
    }
    public fun divide_into_n<T>(self: &mut MultiToken<T>, n: u64, ctx: &mut TxContext): vector<MultiToken<T>> {
        assert!(n > 0, EInvalidArg);
        //verfiy can divide here.
        let ii = 0;
        let num_ids = vec_map::size(&self.balances);
        while(ii < num_ids){
            let (_token_id,self_token_balance) = vec_map::get_entry_by_idx(&self.balances,ii);
            assert!(n <= balance::value(self_token_balance), ENotEnough);
            ii = ii + 1;
        };

        let vec = vector::empty<MultiToken<T>>();

        let i = 0;
        while ({
                spec {
                    invariant i <= n-1;
                    invariant ctx.ids_created == old(ctx).ids_created + i;
                };
                i < n - 1}) 
            {
                let splited_multitoken = MultiToken{
                id : object::new(ctx),
                balances : vec_map::empty()
            };

            let ti = 0;
            while({ti < num_ids}){

                let (token_id,self_token_balance) = vec_map::get_entry_by_idx_mut(&mut self.balances,ti);
                spec {invariant self_token_balance.value == old(self_token_balance).value - (i * split_amount);};
                
                let split_amount = balance::value(self_token_balance) / n;
                let splited_balance = balance::split(self_token_balance,split_amount);
                vec_map::insert(&mut splited_multitoken.balances,*token_id,splited_balance);
                ti = ti + 1;
            };
            vector::push_back(&mut vec, splited_multitoken);
            i = i + 1;
        };

        (vec)
    }
    public fun value<T>(self: &MultiToken<T>,token_id:u64) : u64 {
       if(!vec_map::contains(&self.balances,&token_id))
            return 0;
        let token_balance = vec_map::get(&self.balances,&token_id);
        return balance::value(token_balance)
    }
    public fun has_token<T>(self: &MultiToken<T>,token_id:u64) : bool {
       return vec_map::contains(&self.balances,&token_id)
    }
}