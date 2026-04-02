module pixel_pet_game::pixel_pet {
    use std::string::{Self, String};
    use std::signer;
    use std::option;
    use aptos_framework::object::{Self, Object, ConstructorRef, ExtendRef};
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::account;
    use aptos_framework::event;
    use aptos_framework::primary_fungible_store;

    // =============================================
    // CONSTANTS
    // =============================================
    const FEE_PER_ACTION: u64 = 1000000; // 0.01 APT (adjust as needed)
    const DECAY_INTERVAL: u64 = 86400;    // 1 day in seconds
    const MAX_STAT: u8 = 100;

    // =============================================
    // EVENTS
    // =============================================
    #[event]
    struct PetCreated has drop, store {
        pet: Object<PixelPet>,
        owner: address,
        name: String,
    }

    #[event]
    struct ActionPerformed has drop, store {
        pet: Object<PixelPet>,
        action: String,
        apt_paid: u64,
    }

    // =============================================
    // CORE RESOURCE
    // =============================================
    struct PixelPet has key {
        name: String,
        image_uri: String,        // Shelby blob URL (e.g. https://api.shelby.xyz/.../your-pixel-pet.png)
        hunger: u8,
        happiness: u8,
        level: u8,
        last_interaction: u64,    // timestamp::now_seconds()
        extend_ref: ExtendRef,    // for owner-only mutations
    }

    // =============================================
    // ENTRY FUNCTIONS
    // =============================================

    /// Create a new pixel pet (costs 0.05 APT mint fee)
    public entry fun create_pet(
        owner: &signer,
        name: String,
        image_uri: String   // ← Upload to Shelby first!
    ) {
        let owner_addr = signer::address_of(owner);
        
        // Pay mint fee to treasury (or burn)
        let fee = coin::withdraw<AptosCoin>(owner, 5000000); // 0.05 APT
        // In production, transfer to a game treasury object instead of burning
        coin::burn(fee, &aptos_framework::aptos_coin::get_metadata());

        // Create object
        let constructor_ref = object::create_named_object(owner, *string::bytes(&name));
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        let pet_obj = object::object_from_constructor_ref<PixelPet>(&constructor_ref);

        let pet = PixelPet {
            name,
            image_uri,
            hunger: 80,
            happiness: 80,
            level: 1,
            last_interaction: timestamp::now_seconds(),
            extend_ref,
        };

        move_to(&object::generate_signer(&constructor_ref), pet);

        event::emit(PetCreated { pet: pet_obj, owner: owner_addr, name });
    }

    /// Feed your pet (costs APT)
    public entry fun feed(owner: &signer, pet: Object<PixelPet>) {
        assert!(object::is_owner(pet, signer::address_of(owner)), 1); // only owner
        
        let fee = coin::withdraw<AptosCoin>(owner, FEE_PER_ACTION);
        coin::burn(fee, &aptos_framework::aptos_coin::get_metadata());

        let pet_mut = borrow_mut(pet);
        pet_mut.hunger = MAX_STAT;
        pet_mut.last_interaction = timestamp::now_seconds();

        event::emit(ActionPerformed { pet, action: string::utf8(b"feed"), apt_paid: FEE_PER_ACTION });
    }

    /// Play with your pet (costs APT)
    public entry fun play(owner: &signer, pet: Object<PixelPet>) {
        assert!(object::is_owner(pet, signer::address_of(owner)), 1);

        let fee = coin::withdraw<AptosCoin>(owner, FEE_PER_ACTION);
        coin::burn(fee, &aptos_framework::aptos_coin::get_metadata());

        let pet_mut = borrow_mut(pet);
        pet_mut.happiness = MAX_STAT;
        pet_mut.last_interaction = timestamp::now_seconds();

        // Level up chance
        if (pet_mut.level < 100 && pet_mut.happiness > 70 && pet_mut.hunger > 70) {
            pet_mut.level = pet_mut.level + 1;
        };

        event::emit(ActionPerformed { pet, action: string::utf8(b"play"), apt_paid: FEE_PER_ACTION });
    }

    /// View current stats (view function)
    #[view]
    public fun get_pet_stats(pet: Object<PixelPet>): (String, String, u8, u8, u8, u64) {
        let p = borrow(pet);
        (p.name, p.image_uri, p.hunger, p.happiness, p.level, p.last_interaction)
    }

    // =============================================
    // INTERNAL HELPERS
    // =============================================
    inline fun borrow(pet: Object<PixelPet>): &PixelPet {
        borrow_global<PixelPet>(object::object_address(&pet))
    }

    inline fun borrow_mut(pet: Object<PixelPet>): &mut PixelPet {
        borrow_global_mut<PixelPet>(object::object_address(&pet))
    }

    // Optional: decay function (call from frontend every few hours)
    public entry fun decay_stats(owner: &signer, pet: Object<PixelPet>) {
        let now = timestamp::now_seconds();
        let p = borrow_mut(pet);
        if (now > p.last_interaction + DECAY_INTERVAL) {
            let days = ((now - p.last_interaction) / DECAY_INTERVAL) as u8;
            if (p.hunger > days * 10) p.hunger = p.hunger - days * 10 else p.hunger = 0;
            if (p.happiness > days * 8) p.happiness = p.happiness - days * 8 else p.happiness = 0;
            p.last_interaction = now;
        };
    }
}
