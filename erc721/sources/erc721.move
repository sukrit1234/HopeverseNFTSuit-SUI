module erc721::erc721 {

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
    
    use erc721::erc721_metadata::{Self,ERC721Metadata};

    /// For when a type passed to create_supply is not a one-time witness.
    const EBadWitness: u64 = 0;

    /// For when invalid arguments are passed to a function.
    const EInvalidArg: u64 = 1;

    /// For when trying to split a coin more times than its balance allows.
    const ENotEnough: u64 = 2;

    const ENotContractOwner: u64 = 3;

    const EItemUndefine: u64 = 4;

    const ENotWhitelisted: u64 = 5;

    const ENoTokenInBox: u64 = 6;

    const EArgumentDimensionMismatch: u64 = 7;

    const EOverMaxSupply: u64 = 8;

    const ENoSupplyToBurn: u64 = 9;

    const EFatalDuplicateTokenId: u64 = 10;

    const ENoTokenIdMismatch : u64 = 11;

    struct ItemBox<phantom T> has key, store {
        id: UID,
        items: vector<u64>
    }

    struct CollectionCapability<phantom T> has key, store {
        id: UID,
        collection_object_id : ID
    }

    //Metadata of collection
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
        collection_object_id : ID
    }

    //Track running no max supply and total supply.
    struct Collection<phantom T> has key, store {
        id: UID,
        runing_no : u64,
        total_supply : u64,
        max_supply : u64,
        unreveal_name : vector<u8>,
        unreveal_desc : vector<u8>,
        unreveal_token_uri : vector<u8>,
        //Keep item id and all of items object is shared object.
        items : VecMap<u64,ID> 
    }
    struct NFTDefinition<phantom T> has key, store {
        id: UID,
        metadata : ERC721Metadata,
        collection_id : ID //Keep relation with collection
    }

    struct CollectionCreated<phantom T> has copy, drop {
        metadata_id : ID,
        capability_object_id : ID,
        collection_object_id : ID,
    }
    struct ItemMinted<phantom T> has copy, drop {
        id : ID, 
        token_id : u64
    }

    public fun create_collection<T: drop>(witness: T,symbol: vector<u8>,name: vector<u8>,description: vector<u8>,max_supply : u64,icon_url: Option<Url>,ctx: &mut TxContext){
        // Make sure there's only one instance of the type T
        assert!(sui::types::is_one_time_witness(&witness), EBadWitness);

        let collection_object = Collection<T> {
            id: object::new(ctx),    
            runing_no : 0,
            total_supply : 0,
            max_supply : max_supply,
            unreveal_name : name,
            unreveal_desc : name,
            unreveal_token_uri : b"",
            items : vec_map::empty(),
        };
        let collection_object_id = object::uid_to_inner(&collection_object.id);

        let capability_object = CollectionCapability<T> {
            id: object::new(ctx),    
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

    public entry fun change_owner<T: drop>(gm : CollectionCapability<T>, new_owner: address, ctx: &mut TxContext){        
        let signer_addr = tx_context::sender(ctx);
        assert!(signer_addr != new_owner,ENotContractOwner);
        transfer::transfer(gm, new_owner);
    }

    
    fun do_mint<T:drop>(collection : &mut Collection<T>, ctx: &mut TxContext) : u64{
        
        let next_id = collection.runing_no + 1;
        let collection_id = object::uid_to_inner(&collection.id);
        
        //Mint new token.
        let item = NFTDefinition<T>{
            id: object::new(ctx),
            metadata : erc721_metadata::new(erc721_metadata::new_token_id(next_id), collection.unreveal_name, collection.unreveal_token_uri),
            collection_id
        };

        let item_id = object::uid_to_inner(&item.id);
        vec_map::insert(&mut collection.items,next_id,item_id);

        collection.total_supply = collection.total_supply + 1;
        collection.runing_no = next_id;
        transfer::share_object(item);
        (next_id)
    }
    fun new_box_and_transfer<T:drop>(new_token_ids : vector<u64>, ctx: &mut TxContext){
        let box = ItemBox<T>{
            id : object::new(ctx),
            items: new_token_ids
        };
        let sender_address = tx_context::sender(ctx);
        transfer::transfer(box,sender_address);
    }

    public entry fun mint<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,box :&mut ItemBox<T>,amount : u64, ctx: &mut TxContext){       
        mint_to_box(collection,box,amount,ctx);
    }
    public entry fun mint_new<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,amount : u64, ctx: &mut TxContext){       
        mint_to_new_box(collection,amount,ctx);
    }
    public entry fun burn<T:drop>(collection : &mut Collection<T>,box :&mut ItemBox<T>,token_id : u64){       
        burn_from_box(collection,box,token_id);
    }

    public fun mint_to_box<T:drop>(collection : &mut Collection<T>,box : &mut ItemBox<T>,amount : u64, ctx: &mut TxContext){       
        assert!((collection.total_supply + amount) <= collection.max_supply,EOverMaxSupply);        
        let i = 0;
        while(i < amount){
            let minted_token_id = do_mint(collection,ctx);
            vector::push_back(&mut box.items,minted_token_id);
            i = i + 1;
        }
    }
    public fun mint_to_new_box<T:drop>(collection : &mut Collection<T>,amount : u64, ctx: &mut TxContext){              
        assert!((collection.total_supply + amount) <= collection.max_supply,EOverMaxSupply);        
        let i = 0;
        let minted_token_ids = vector::empty();
        while(i < amount){
            let minted_token_id = do_mint(collection,ctx);
            vector::push_back(&mut minted_token_ids,minted_token_id);
            i = i + 1;
        };
        new_box_and_transfer<T>(minted_token_ids,ctx);
    }    
    public fun burn_from_box<T:drop>(collection : &mut Collection<T>,box :&mut ItemBox<T>,token_id : u64){       
        assert!(collection.total_supply > 0,ENoSupplyToBurn);
        assert!(vec_map::contains(&collection.items,&token_id),EItemUndefine);
        
        let (exists,item_index) = vector::index_of(&box.items,&token_id);
        assert!(exists,ENoTokenInBox);

        vec_map::remove(&mut collection.items,&token_id);
        vector::swap_remove(&mut box.items,item_index);
        collection.total_supply = collection.total_supply - 1;
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
    public fun get_capability_id<T:drop>(metadata : &CollectionMetadata<T>) : ID{
        metadata.capability_object_id
    }
    public fun get_collection_id<T:drop>(metadata : &CollectionMetadata<T>) : ID{
        metadata.collection_object_id
    }
    public fun get_collection_unreveal_name<T:drop>(collection : &Collection<T>) : string::String{
       string::utf8(collection.unreveal_name)
    }
    public fun get_collection_unreveal_desc<T:drop>(collection : &Collection<T>) : string::String{
        string::utf8(collection.unreveal_desc)
    }
    public fun get_collection_unreveal_token_uri<T:drop>(collection : &Collection<T>) : Url{
        let uri_str = ascii::string(collection.unreveal_token_uri);
        url::new_unsafe(uri_str)
    }
    public fun get_max_supply<T:drop>(collection : &Collection<T>) : u64{
        collection.max_supply
    }
    public fun get_total_supply<T:drop>(collection : &Collection<T>) : u64{
        collection.total_supply
    }
    public entry fun update_item_name<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,item : &mut NFTDefinition<T>, name: vector<u8>, _ctx: &mut TxContext){        
        let collection_id = object::uid_to_inner(&collection.id);
        assert!(collection_id == item.collection_id,EItemUndefine);
        erc721_metadata::update_name(&mut item.metadata,name);
    }
    public entry fun update_item_uri<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>,item : &mut NFTDefinition<T>,token_uri: vector<u8>, _ctx: &mut TxContext){
        let collection_id = object::uid_to_inner(&collection.id);
        assert!(collection_id == item.collection_id,EItemUndefine);
        erc721_metadata::update_token_uri(&mut item.metadata,token_uri);
    }
    public entry fun update_maxsupply<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>, max_supply : u64){
        collection.max_supply = max_supply;
    }
    public entry fun update_unreveal_name<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>, name: vector<u8>){
        collection.unreveal_name = name;
    }
    public entry fun update_unreveal_desc<T:drop>(_gm:& CollectionCapability<T>,collection : &mut Collection<T>, desc: vector<u8>){
        collection.unreveal_desc = desc;
    }
    public entry fun update_unreveal_token_uri<T:drop>(_colcap: &CollectionCapability<T>, collection: &mut Collection<T>, uri: vector<u8>) {
        collection.unreveal_token_uri =  uri;
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

    public fun join<T>(self: &mut ItemBox<T>, a: ItemBox<T>) {
        
        let ItemBox { id, items } = a;
        object::delete(id);

        while(!vector::is_empty(&items)){
            let token_id = vector::pop_back(&mut items);
            assert!(!vector::contains(&self.items,&token_id),EFatalDuplicateTokenId);
            vector::push_back(&mut self.items,token_id);
        };
        vector::destroy_empty(items);
    }
    public fun split<T>(self: &mut ItemBox<T>,split_token_id: u64, ctx: &mut TxContext): ItemBox<T> {
 
        let (exists,item_index) = vector::index_of<u64>(&self.items,&split_token_id);
        assert!(exists,ENoTokenInBox);

        let out_token_id = vector::swap_remove<u64>(&mut self.items,item_index);
        assert!(out_token_id == split_token_id,ENoTokenIdMismatch);
        let new_one = ItemBox<T> {
            id : object::new(ctx),
            items : vector::empty()
        };
        vector::push_back(&mut new_one.items,split_token_id);
        (new_one)
    }
    public fun split_multi<T>(self: &mut ItemBox<T>,split_token_ids: vector<u64>, ctx: &mut TxContext): ItemBox<T> {
       
        let num_ids = vector::length(&split_token_ids);
        let i = 0;
        while(i < num_ids){
            let token_id = vector::borrow(&split_token_ids,i);
            assert!(vector::contains(&self.items,token_id),ENoTokenInBox);
            i = i + 1;
        };

        let new_one = ItemBox {
            id : object::new(ctx),
            items : vector::empty()
        };

        let ii = 0;
        while(ii < num_ids){
            let token_id = vector::borrow(&split_token_ids,ii);
            let (exists,item_index) = vector::index_of<u64>(&self.items,token_id);
            assert!(exists,ENoTokenInBox);
            
            let out_token_id = vector::swap_remove(&mut self.items,item_index);
            assert!(out_token_id == (*token_id),ENoTokenIdMismatch);
            vector::push_back(&mut new_one.items,out_token_id);
            
            ii = ii + 1;
        };
        (new_one)
    }
    
}