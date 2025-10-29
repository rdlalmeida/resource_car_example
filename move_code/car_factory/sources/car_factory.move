module car_factory::car_factory;

use std::string;
use sui::event;
use sui::table::Table;

public struct ModuleOwner has key, store {
    id: UID,
    owner: address,
}

/// The Car object, as implemented in Sui-Move
public struct Car has key, store {
    id: UID,
    owner: address,
    color: string::String,
    licence_plate: string::String,
    running: bool,
    insurance_policy: string::String,
}

public struct Garage has key {
    id: UID,
    garage_owner: address,
    stored_cars: Table<ID, Car>,
}

// ========= Init Functions =========
fun init(ctx: &mut sui::tx_context::TxContext) {
    let new_module_owner: ModuleOwner = ModuleOwner {
        id: object::new(ctx),
        owner: ctx.sender(),
    };

    transfer::public_transfer(new_module_owner, ctx.sender())
}

// ========= Events =========
public struct CarCreated has copy, drop {
    car_id: ID,
    car_owner: address,
    licence_plate: string::String,
}

public struct CarStarted has copy, drop {
    car_id: ID,
    car_owner: address,
    licence_plate: string::String,
}

public struct CarStopped has copy, drop {
    car_id: ID,
    car_owner: address,
    licence_plate: string::String,
}

public struct CarDestroyed has copy, drop {
    car_id: ID,
    car_owner: address,
    licence_plate: string::String,
}

// ========= Public view functions =========
public fun isCarRunning(car: &Car): &bool {
    &car.running
}

// ========= Public edit functions =========
// createCar is a private entry function, i.e., it can only be invoked by transactions and not by other modules
entry fun createCar(
    _color: string::String,
    _licence_plate: string::String,
    _insurance_policy: string::String,
    module_owner: &ModuleOwner,
    garage: &mut Garage,
    car_owner: address,
    ctx: &mut sui::tx_context::TxContext,
) {
    // Ensure that only the owner of the module can create new cars
    assert!(module_owner.owner == ctx.sender());

    // And that the owner of the garage provided and the new car are the same
    assert!(car_owner == garage.garage_owner);

    // Create the new car
    let new_car: Car = Car {
        id: object::new(ctx),
        owner: car_owner,
        color: _color,
        licence_plate: _licence_plate,
        running: false,
        insurance_policy: _insurance_policy,
    };

    // Emit the CarCreated event
    event::emit(CarCreated {
        car_id: new_car.id.to_inner(),
        car_owner: car_owner,
        licence_plate: new_car.licence_plate,
    });
    garage.stored_cars.add(new_car.id.to_inner(), new_car);
}

entry fun destroyCar(car_id: ID, garage: &mut Garage) {
    let car_to_destroy: Car = garage.stored_cars.remove(car_id);

    let Car {
        id: uid,
        owner: car_owner,
        color: _,
        licence_plate: destroyed_licence_plate,
        running: _,
        insurance_policy: _,
    } = car_to_destroy;

    event::emit(CarDestroyed {
        car_id: uid.to_inner(),
        car_owner: car_owner,
        licence_plate: destroyed_licence_plate,
    });

    uid.delete();
}

public fun storeCar(carToStore: Car, garage: &mut Garage) {
    // Ensure that the owner of the car to store and the garage are the same
    assert!(carToStore.owner == garage.garage_owner);

    // Ensure that the Car is not in the garage already
    assert!(!garage.stored_cars.contains(carToStore.id.to_inner()));

    // Move the Car into the Garage
    garage.stored_cars.add(carToStore.id.to_inner(), carToStore);
}

public fun retrieveCar(carId: ID, garage: &mut Garage): Car {
    // Check first if the car in question is in the garage reference provided
    assert!(garage.stored_cars.contains(carId));

    // The car exists. Retrieve it from the Garage
    let carToReturn: Car = garage.stored_cars.remove(carId);

    // And return the car back to the caller
    return carToReturn
}

entry fun startCar(garage: &mut Garage, car_id: ID) {
    // Check if the car in question is already running
    if (!garage.stored_cars[car_id].running) {
        // If not, set it as so
        *&mut garage.stored_cars[car_id].running = true;
    };

    // Emit the CaStarted event
    event::emit(CarStarted {
        car_id: car_id,
        car_owner: garage.garage_owner,
        licence_plate: garage.stored_cars[car_id].licence_plate,
    });
}

entry fun stopCar(garage: &mut Garage, car_id: ID) {
    // Check if the car in question is already stopped
    if (garage.stored_cars[car_id].running) {
        // If not, stop it
        *&mut garage.stored_cars[car_id].running = false;
    };

    // Emit the CarStopped event
    event::emit(CarStopped {
        car_id: car_id,
        car_owner: garage.garage_owner,
        licence_plate: garage.stored_cars[car_id].licence_plate,
    });
}
