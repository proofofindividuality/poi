#Proof of Individuality

POIs (proof-of-individuality) are smart-assets that are hosted on the Ethereum network. They solve [one of the hard problems in crypto](https://www.reddit.com/r/CryptoUBI/comments/2v2gi6/proof_of_identityproof_of_person_the_elephant_in/) - how do you prove that a person only has one account within the system?

Join the POI project on Slack,
http://poiproject.herokuapp.com 

##How

Through person-to-person verification. Users are grouped together by random in groups of 5 or so, and every group does a video hangout at the exact same time, that lasts around 10 minutes or so. Users check so that the others in their group aren't doing another hangout at the same time. They then sign each other's POIs and verify them. Once the hangouts are finished and all POIs have been verified, everyone will know that each POI represents a unique human being. 

### Overview of the subcontracts


**depositGovernance.sol**

Manages the anti-spam deposits, and also includes a system to vote on the size of the anti-spam deposit. 
A new contract is created each round, and the old one sucidides.

**generatePOIs.sol** 

Issues undivisible POI tokens to all verified users. A new contract is created after each round, and the old one suicides.
 
**hangout.sol**

Manages the verification within the hangouts. Includes the ASF system that 'gamifies the hangouts' by using a point system
instead of one-vote-per-person, allowing users in a hangout to direct and steer each others attention more. 
A new contract is created for each hangout.

**registration.sol**

Manages the registration of users each month, assing them into groups by random, and boots up hangout contracts. 
New contract is created each round.

**poi.sol** 

Main contract. Boots up the other contracts, manages scheduling, and integrates some function call


### FAQ

**Could you expand a bit on how the anti-spam mechanism works?**

The randomization makes it hard to gain control of entire groups, but controlling 2x or more the total number of users is a way to bypass that. Anti-spam deposits make it very expensive to perform this attack.
