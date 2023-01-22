## ERC1155 Module (Multi Token)
It's compose with 4 module. Functional on erc1155 module likely with sui::Coin<T> but implement along ethereum ERC1155 Standard.

 + **balance** : very similar to sui::balance, just remove onetime witness from create_supply<T>() to make each item in erc1155 collection can create supply data.
 + **erc1155** : main module for erc1155 (Multi Token implementation)
 + **erc1155_metadata** : module that define Metadata for each erc1155 token with read and write accessor for ERC1155Metadata
 + **pay** : module that modify from sui::Coin<T> but use for erc1155::collection::MultiToken<T>


## erc1155 important methods
 + **create_collection<T: drop>(...)**
It's very similar functional like create_currency on sui::coin module. It's will create
    + **CollectionMetadata<T>** metadata for collection including name , symbol , description , icon_url,capability_object_id,collection_object_id , It's sui move shared object.   
    + **CollectionCapability<T>** similar **TreasureCap<T>** on sui::coin - Admin or module publisher owned this object. and change transfer by change_owner.
    + **Collection<T>** shared object that hold deinition of each token (item) in collection.
+ **define_item<T:drop>(...)** deine token in collection and token_id will emitted via ItemDefined event.
+ other function is self explanation. and you can see use case in [Hopeverse Genesis] (https://github.com/sukrit1234/HopeverseNFTSuit-SUI/edit/main/hopeversegenesis/)
