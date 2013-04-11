assert player1_alive : factories_1 > 0 "player one lives"
assert player2_alive : factories_2 > 0 "player two lives"

source turn
turn --> player_1
turn --> player_2

auto pool player_1
auto pool player_2

auto drain choose_1
auto drain choose_2

auto pool saveAttack_1
auto pool saveDefence_1
auto pool saveFactory_1

auto pool saveAttack_2
auto pool saveDefence_2
auto pool saveFactory_2

auto gate chooseAttack_1
auto gate chooseAttack_2
auto gate chooseDefence_1
auto gate chooseDefence_2
auto gate chooseFactory_1
auto gate chooseFactory_2

player_1 --> saveAttack_1
player_1 --> saveDefence_1
player_1 --> saveFactory_1

player_2 --> saveAttack_2
player_2 --> saveDefence_2
player_2 --> saveFactory_2

saveAttack_1 -all -> chooseAttack_1
saveDefence_1 -all -> chooseDefence_1
saveFactory_1 -all -> chooseFactory_1

saveAttack_2 -all -> chooseAttack_2
saveDefence_2 -all -> chooseDefence_2
saveFactory_2 -all -> chooseFactory_2

chooseFactory_2 -all-> choose_2
chooseDefence_2 -all-> choose_2
chooseAttack_2 -all-> choose_2

chooseFactory_1 -all-> choose_1
chooseDefence_1 -all-> choose_1
chooseAttack_1 -all-> choose_1

saveFactory_1 .==1.> chooseAttack_1
saveDefence_1 .==2.> chooseDefence_1
saveFactory_1 .==5.> chooseFactory_1

saveFactory_2 .==1.> chooseAttack_2
saveDefence_2 .==2.> chooseDefence_2
saveFactory_2 .==5.> chooseFactory_2

chooseAttack_1 .*.> buyAttack_1
chooseAttack_2 .*.> buyAttack_2

chooseFactory_1 .*.> buyFactory_1
chooseFactory_2 .*.> buyFactory_2

chooseDefence_1 .*.> buyDefence_1
chooseDefence_2 .*.> buyDefence_2


// *********************************************************************************
//  * Player 1. Without components we have to replicate behavior.
//  ********************************************************************************
pool reserve_1 at 100      //Gold reserve (starts at 100)
auto pool resources_1      //Gold resources (used for purchases)
pool factories_1 at 1      //factories producing income (start with 1)
pool defence_1 at 1        //defending Attack and Defence units
pool attack_1         //attacking Attack units

auto drain killed_1             //drain kills attack or defence
auto drain destroyed_1     //drain destroys factories (* pulls all)

user all converter buyDefence_1  //convert all required Gold to Defence
user all converter buyAttack_1   //convert all required Gold to Attack
user all converter buyFactory_1  //convert all required Gold to Factory

reserve_1 -factories_1 * 0.25 + 1-> resources_1 //flow 0.25 * factories Gold to resources
resources_1 -5-> buyFactory_1             //buyFactory consumes 5 Gold from resources
buyFactory_1 --> factories_1              //buyFactory produces 1 Factory to factories
resources_1 -1-> buyDefence_1             //buyDefence consumes 2 Gold from resources
buyDefence_1 --> defence_1                //buyDefence produces 1 Defence to defence
resources_1 -2-> buyAttack_1               //buyAttack consumes 1 Gold from resources
buyAttack_1 --> attack_1                  //buyAttack produces 1 Attack to attack

factories_1 -all-> destroyed_1   //factories destuction rate
defence_1 -attack_2 * 0.3-> killed_1        //defence casualty rate
attack_1 -defence_2 * 0.1-> killed_1        //attack casualty rate
defence_1 .==0.> destroyed_1              //zero defence enables destroyed

// *********************************************************************************
//  * Player 2. Without components we have to replicate behavior.
//  ********************************************************************************
pool reserve_2 at 100      //Gold reserve (starts at 100)

auto pool resources_2      //Gold resources (used for purchases)
pool factories_2 at 1      //factories producing income (start with 1)
pool defence_2 at 1        //defending Attack and Defence units
pool attack_2              //attacking Attack units

auto drain killed_2             //drain kills attack or defence
auto drain destroyed_2     //drain destroys factories (* pulls all)

user all converter buyDefence_2  //convert all required Gold to Defence
user all converter buyAttack_2   //convert all required Gold to Attack
user all converter buyFactory_2  //convert all required Gold to Factory

reserve_2 -factories_2 * 0.25 + 1-> resources_2 //flow 0.25 * factories Gold to resources

resources_2 -5-> buyFactory_2             //buyFactory consumes 5 Gold from resources

buyFactory_2 --> factories_2              //buyFactory produces 1 Factory to factories

resources_2 -1-> buyDefence_2             //buyDefence consumes 2 Gold from resources
buyDefence_2 --> defence_2                //buyDefence produces 1 Defence to defence
resources_2 -2-> buyAttack_2               //buyAttack consumes 1 Gold from resources
buyAttack_2 --> attack_2                  //buyAttack produces 1 Attack to attack


factories_2 -all-> destroyed_2   //factories destuction rate
defence_2 -attack_1 * 0.3-> killed_2        //defence casualty rate
attack_2 -defence_1 * 0.1-> killed_2        //attack casualty rate
defence_2 .==0.> destroyed_2              //zero defence enables destroyed

