
module multitoken_craft::erc1155_craft_system {

    use std::string;
    use sui::address;
    use sui::object::{Self,UID,ID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self,TxContext};
    use sui::vec_map::{Self,VecMap};
    use sui::coin::{Self,Coin};
    use erc1155::collection::{Self,MultiToken,Collection,CollectionCapability};
    use multitoken_craft::erc1155_craft_formula::{Self,CraftFormula};

    const ECraftCollectionUndefined: u64 = 4;

    const EParameterDimensionMismatch: u64 = 5;

    const ENotWhitelisted: u64 = 9;

    const ETemplateUndefined: u64 = 10;

    const EInsufficientInputs: u64 = 11;

    const EInsufficientFund: u64 = 11;

    const ETemplateNotEnabled: u64 = 12;
    
    const EInputTokenUndefined: u64 = 13;

    const EOutputTokenUndefined: u64 = 14;

    const EZeroCraftCount: u64 = 15;

    const EZeroInputAmount: u64 = 16;

    const EZeroOutputAmount: u64 = 17;

    const ESameMerchantAddress: u64 = 18;

    const ENoAnyInputs: u64 = 19;

    const ENoAnyOutputs: u64 = 20;
    
    struct CraftTemplateInfo<phantom Currency> has key, store {
        id: UID,
        name: string::String,
        description : string::String, 
        collection_id : ID,
        operation_price : u64,
        formula : CraftFormula,
        enabled : bool
    }
    struct CraftCollection<phantom Currency> has key, store {
        id: UID,
        running_no : u64,
        collection_id : ID,
        templates : VecMap<u64,CraftTemplateInfo<Currency>>,
        merchant_address : address
    }

    struct CraftCollectionCreated has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct CraftCollectionRemoved has copy, drop {
        id : ID,
        collection_id : ID
    }
    struct CraftTemplateCreated has copy, drop {
        id : ID,
        template_id : u64
    }
    public entry fun create_craft_collection<T:drop,Currency>(gm : &CollectionCapability<T>,ctx: &mut TxContext){
        
        let collection_id = collection::get_collection_id_from_owner(gm);
        let craftSystem = CraftCollection<Currency> {
            id: object::new(ctx), 
            running_no : 0,
            collection_id : collection_id, 
            templates : vec_map::empty(),
            merchant_address : tx_context::sender(ctx)
        };

        let craftsys_id = object::uid_to_inner(&craftSystem.id);
        transfer::share_object(craftSystem);

        event::emit(CraftCollectionCreated {id : craftsys_id,collection_id : collection_id});
    }
    //Remove whitelist shared objet (in not real remove just cut reference make it invalid)
    public entry fun unuse_craft_collection<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>){
       
        let collection_id = collection::get_collection_id_from_owner(gm);
        assert!(collection_id == craftcol.collection_id,ECraftCollectionUndefined);
       
        let craft_id = object::uid_to_inner(&craftcol.id);
        event::emit(CraftCollectionRemoved {id : craft_id,collection_id});
        craftcol.collection_id = object::id_from_address(address::from_u256(0));
    }
    
    public entry fun change_merchant<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,new_merchant_address : address){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(craftcol.merchant_address != new_merchant_address,ESameMerchantAddress);
        craftcol.merchant_address = new_merchant_address;
    }

    public entry fun define_craft_template<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,name : vector<u8>,description : vector<u8>,
            price : u64,in_token_ids : vector<u64>,in_token_amounts : vector<u64>,out_token_ids:vector<u64>,out_token_amounts : vector<u64>,ctx: &mut TxContext){

        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        let template_id = define_empty_craft_template_internal(craftcol,name,description,price,ctx);
        let template = vec_map::get_mut(&mut craftcol.templates,&template_id);

        erc1155_craft_formula::initial_input_items(&mut template.formula,&in_token_ids,&in_token_amounts);
        erc1155_craft_formula::initial_output_items(&mut template.formula,&out_token_ids,&out_token_amounts);

        let tplobj_id = object::uid_to_inner(&template.id);
        event::emit(CraftTemplateCreated {id : tplobj_id,template_id : template_id})

    }
    public entry fun define_empty_craft_template<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,name : vector<u8>,description : vector<u8>,price : u64,ctx: &mut TxContext){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        let template_id = define_empty_craft_template_internal(craftcol,name,description,price,ctx);
        let template = vec_map::get(&craftcol.templates,&template_id);

        let tplobj_id = object::uid_to_inner(&template.id);
        event::emit(CraftTemplateCreated {id : tplobj_id,template_id : template_id})
    }
    public entry fun set_craft_template_enabled<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,enabled : bool){

        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);

        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        craft_template.enabled = enabled;
    }
    public entry fun update_craft_template_name<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,name : vector<u8>){

        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);

        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        craft_template.name = string::utf8(name);
    }
    public entry fun update_craft_template_description<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,description : vector<u8>){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);

        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        craft_template.description = string::utf8(description);
    }
    public entry fun update_craft_template_price<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,price : u64){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);

        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        craft_template.operation_price = price;
    }

    public entry fun update_input_item<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,token_id : u64,amount : u64){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::update_input_item(&mut craft_template.formula,token_id,amount);
    }
    public entry fun remove_input_item<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id:u64,token_id : u64){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::remove_input_item(&mut craft_template.formula,token_id);
    }
    public entry fun update_output_item<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id:u64,token_id : u64,amount : u64){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::update_output_item(&mut craft_template.formula,token_id,amount);
    }
    public entry fun remove_output_item<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id:u64,token_id : u64){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::remove_output_item(&mut craft_template.formula,token_id);
    }

    public entry fun update_input_items<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,token_ids : vector<u64>,amounts : vector<u64>){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::update_input_items(&mut craft_template.formula,&token_ids,&amounts);
    }
    public entry fun update_output_items<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,token_ids : vector<u64>,amounts : vector<u64>){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::update_output_items(&mut craft_template.formula,&token_ids,&amounts);
    }

    public entry fun remove_input_items<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,token_ids : vector<u64>){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::remove_input_items(&mut craft_template.formula,&token_ids);
    }
    public entry fun remove_output_items<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol :&mut CraftCollection<Currency>,template_id : u64,token_ids : vector<u64>){
        assert!(is_valid_craftcollection(gm,craftcol),ECraftCollectionUndefined);
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);
        
        let craft_template = vec_map::get_mut(&mut craftcol.templates,&template_id);
        erc1155_craft_formula::remove_output_items(&mut craft_template.formula,&token_ids);
    }

    public fun is_definded<Currency>(craftcol : &CraftCollection<Currency>,template_id : u64) : bool {
        vec_map::contains(&craftcol.templates,&template_id)
    }
    public fun is_valid_craftcollection<T:drop,Currency>(gm : &CollectionCapability<T>,craftcol : &CraftCollection<Currency>) : bool {   
        let collection_id = collection::get_collection_id_from_owner(gm);
        craftcol.collection_id == collection_id
    }

    fun define_empty_craft_template_internal<Currency>(craftcol :&mut CraftCollection<Currency>,name : vector<u8>,description : vector<u8>,price : u64,ctx: &mut TxContext) : u64 {
         
         let next_id = craftcol.running_no + 1;
         let template = CraftTemplateInfo{
            id : object::new(ctx),
            name: string::utf8(name),
            description : string::utf8(description),
            collection_id : craftcol.collection_id,
            operation_price : price,
            formula : erc1155_craft_formula::empty(),
            enabled : true
         };
         craftcol.running_no = next_id;
        vec_map::insert(&mut craftcol.templates,next_id,template);
        
        (next_id)
    }

    public fun craft<T:drop,Currency>(collection : &mut Collection<T>,craftcol : &CraftCollection<Currency>,template_id : u64,album :&mut MultiToken<T>,coin : &mut Coin<Currency>,apply_count : u64,ctx: &mut TxContext){

        //Check apply count is valid ?.
        assert!(apply_count > 0,EZeroCraftCount);

        //Check template undefined ?
        assert!(is_definded(craftcol,template_id),ETemplateUndefined);

        //Check template enabled ?        
        let template = vec_map::get(&craftcol.templates,&template_id);
        assert!(template.enabled,ETemplateNotEnabled);

        let total_fee = template.operation_price*apply_count;
        let current_coin_balance = coin::value(coin);
        assert!(current_coin_balance >= total_fee,EInsufficientFund);

        let ii = 0;
        let input_count = erc1155_craft_formula::get_input_count(&template.formula);
        assert!(input_count > 0,ENoAnyInputs);
        let input_items = erc1155_craft_formula::get_inputs(&template.formula);
        while(ii < input_count){
            let (token_id,amount) = vec_map::get_entry_by_idx(input_items,ii);
        
            //Check input token id defined. ?        
            assert!(collection::is_definded(collection,*token_id),EInputTokenUndefined);

            //Check input amount is valid (>=1)
            assert!((*amount) > 0,EZeroInputAmount);

            //CHeck total input amount to use against available.
            let total_amount = apply_count*(*amount);
            let current_amount = collection::value(album,*token_id);
            assert!(current_amount >= total_amount,EInsufficientInputs);

            ii = ii + 1;
        };

        let oi = 0;
        let output_count = erc1155_craft_formula::get_output_count(&template.formula);
        assert!(output_count > 0,ENoAnyOutputs);

        let output_items = erc1155_craft_formula::get_outputs(&template.formula);
        while(oi < output_count){

            let (token_id,amount) = vec_map::get_entry_by_idx(output_items,oi);

            //Check output token id defined. ?        
            assert!(collection::is_definded(collection,*token_id),EOutputTokenUndefined);

            //Check output amount is valid (>=1)
            assert!((*amount) > 0,EZeroOutputAmount);

            oi = oi + 1;
        };

        let ii = 0;
        while(ii < input_count){

            let (token_id,amount) = vec_map::get_entry_by_idx(input_items,ii);
            
            //Burn inputs.
            let total_amount = apply_count*(*amount);
            collection::burn_amount(collection,album,*token_id,total_amount);
            ii = ii + 1;
        };
    
        let oi = 0;
        while(oi < output_count){

            let (token_id,amount) = vec_map::get_entry_by_idx(output_items,oi);

            //Mint output.
            let total_amount = apply_count*(*amount);
            collection::mint_amount(collection,album,*token_id,total_amount);
            oi = oi + 1;
        };
        
        //Conduct operation fee and send to merchant.
        let operation_fee_coin = coin::split(coin,total_fee,ctx);
        transfer::transfer(operation_fee_coin,craftcol.merchant_address);
    }
}