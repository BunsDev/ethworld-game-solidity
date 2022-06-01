// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "./BaseERC20Ressource.sol";

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "./Planet.sol";
import "./MapUtils.sol";

contract Game is AccessControl {
    struct Ressource {
        BaseERC20Ressource token;
        uint256 baseProductionPerSecond; // How much ressource are generater per second
        uint256 outTransferTax; // Percent of ressources kept when transfering to ERC20
        uint256 startingBalance;
    }

    mapping(uint256 => Ressource) public ressources;

    // balance / production level / bonusmultiplier /lasttimeupdated / maxstorage / storagelevel
    mapping(uint256 => mapping(uint256 => uint256[6])) public planetRessources;

    uint256 public constant MAX_STORAGE_BASE = 1000;
    uint256 public constant ONE_PER_MINUTE = 16660000000000000;

    uint128 public constant DIFFICULTY = 2000;
    uint128 public constant UNIVERSE = 666;
    uint128 public constant MAX_PLANET_SIZE = 400;

    event newPlanetMinted(uint256 id);

    Planet public planetNFT;
    MapUtils public mapUtils;

    constructor(address _planetNFT, address _mapUtils) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        planetNFT = Planet(_planetNFT);
        mapUtils = MapUtils(_mapUtils);
    }

    function newPlanet(
        uint256 x,
        uint256 y,
        uint256 size
    ) public {
        uint256 _id = mapUtils.getPlanetId(x, y);

        planetRessources[_id][0][3] = block.timestamp;
        planetRessources[_id][0][0] = ressources[0].startingBalance;
        planetRessources[_id][0][4] = 10000 * 1 ether;

        planetRessources[_id][1][3] = block.timestamp;
        planetRessources[_id][1][0] = ressources[1].startingBalance;
        planetRessources[_id][1][4] = 10000 * 1 ether;

        planetRessources[_id][2][3] = block.timestamp;
        planetRessources[_id][2][0] = ressources[2].startingBalance;
        planetRessources[_id][2][4] = 10000 * 1 ether;

        planetNFT.mint(msg.sender, _id);
        console.log("UPDATEBL BEFORE/AFTER %s", _id);
        emit newPlanetMinted(_id);
    }

    function registerRessource(
        uint256 _id,
        address _ressource,
        uint256 _baseProductionPerSecond,
        uint256 _outTransferTax,
        uint256 _startingBalance
    ) public {
        ressources[_id] = Ressource(
            BaseERC20Ressource(_ressource),
            _baseProductionPerSecond,
            _outTransferTax,
            _startingBalance
        );
    }

    function getPlanetInfos(uint256 _planet)
        public
        view
        returns (
            address owner,
            uint256 l1,
            uint256 l2,
            uint256 l3,
            uint256 r1,
            uint256 r2,
            uint256 r3
        )
    {
        owner = planetNFT.ownerOf(_planet);
        l1 = planetRessources[_planet][0][1];
        l2 = planetRessources[_planet][1][1];
        l3 = planetRessources[_planet][2][1];
        r1 = getBalance(_planet, 0);
        r2 = getBalance(_planet, 1);
        r3 = getBalance(_planet, 2);
    }

    function updateBalance(uint256 _planet, uint256 _ressource) public {
        console.log(
            "UPDATEBL BEFORE/AFTER %s %s",
            planetRessources[_planet][_ressource][0],
            getBalance(_planet, _ressource)
        );
        
        planetRessources[_planet][_ressource][0] = getBalance(
            _planet,
            _ressource
        );
        planetRessources[_planet][_ressource][3] = block.timestamp;
    }

    function getBalance(uint256 _planet, uint256 _ressource)
        public
        view
        returns (uint256)
    {
        uint256 level = planetRessources[_planet][_ressource][1] + 1;
        if (_ressource == 0) {
            console.log("Balance: ", planetRessources[_planet][_ressource][0]);
            console.log("Level: ", planetRessources[_planet][_ressource][1]);
            console.log("Bonus: ", planetRessources[_planet][_ressource][2]);
            console.log(
                "Last time: ",
                planetRessources[_planet][_ressource][3]
            );
            console.log(
                "Time elapsed: %s",
                block.timestamp - planetRessources[_planet][_ressource][3]
            );
        }
        console.log("PERSEC %s, : ", planetRessources[_planet][_ressource][0]);
        // balance = balance + (BASEPRODUCTION * LEVEL * 1.1 ^ LEVEL)
        uint256 newBalance = planetRessources[_planet][_ressource][0] +
            (((ressources[_ressource].baseProductionPerSecond *
                (level) *
                (33**level * 100)) / 3**level) *
                (block.timestamp - planetRessources[_planet][_ressource][3])) /
            100;
        newBalance = newBalance < planetRessources[_planet][_ressource][4] ? newBalance : planetRessources[_planet][_ressource][4];
        return newBalance;
    }

    function getUpgradeStorageCost(uint256 _ressource, uint256 _level)
        public
        pure
        returns (uint256 r0, uint256 r1)
    {
        if (_ressource == 0) {
            r0 = 1000 * 2**(_level - 1) * 1 ether;
        } else if (_ressource == 1) {
            r0 = 500 * 2**(_level - 1) * 1 ether;
            r1 = 500 * 2**(_level - 1) * 1 ether;
        } else if (_ressource == 2) {
            r0 = 1000 * 2**(_level - 1) * 1 ether;
            r1 = 1000 * 2**(_level - 1) * 1 ether;
        }
    }

    function upgradeStorage(uint256 _planet, uint256 _ressource) public {
        planetRessources[_planet][_ressource][5] += 1;
        uint256 r0;
        uint256 r1;
        (r0, r1) = getUpgradeStorageCost(_ressource, planetRessources[_planet][_ressource][5]);
        _useRessource(_planet, 0, r0);
        if (r1 > 0) {
            _useRessource(_planet, 1, r1);
        }
        planetRessources[_planet][_ressource][4] += planetRessources[_planet][
            _ressource
        ][4];
    }

    function getUpgradeCost(uint256 _ressource, uint256 _level)
        public
        pure
        returns (uint256 r0, uint256 r1)
    {
        uint256 energy;
        if (_ressource == 0) {
            r0 = ((60 * (3**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            r1 = ((15 * (3**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            energy =
                ((10 * (11**(_level - 1) * 100)) / 10**(_level - 1)) *
                10**16;
        } else if (_ressource == 1) {
            r0 = ((48 * (32**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            r1 = ((25 * (32**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            energy =
                ((10 * (11**(_level - 1) * 100)) / 10**(_level - 1)) *
                10**16;
        } else if (_ressource == 2) {
            r0 = ((225 * (3**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            r1 = ((75 * (3**(_level - 1) * 100)) / 2**(_level - 1)) * 10**16;
            energy =
                ((20 * (11**(_level - 1) * 100)) / 10**(_level - 1)) *
                10**16;
        }
    }

    function upgradeRessource(uint256 _planet, uint256 _ressource) public {
        uint256 r0;
        uint256 r1;
        (r0, r1) = getUpgradeCost(
            _ressource,
            planetRessources[_planet][_ressource][1] + 1
        );
 _useRessource(_planet, 0, r0);
_useRessource(_planet, 1, r1);
        planetRessources[_planet][_ressource][1] += 1;
    }

    function _useRessource(
        uint256 _planet,
        uint256 _ressource,
        uint256 _amount
    ) internal {
        updateBalance(_planet, _ressource);
        planetRessources[_planet][_ressource][0] -= _amount;
    }

    function exportRessources(
        address _recipient,
        uint256[] calldata _planets,
        uint256[] calldata _ressources,
        uint256[] calldata _amounts
    ) public {
        for (uint256 i; i < _planets.length; i++) {
            if (_amounts[i] <= getBalance(_planets[i], _ressources[i])) {
                ressources[_ressources[i]].token.mint(
                    _recipient,
                    _amounts[i] -
                        (_amounts[i] *
                            ressources[_ressources[i]].outTransferTax) /
                        100
                );
                // remove planet balance
            }
        }
    }

    function importRessources(
        uint256[] calldata _planets,
        uint256[] calldata _ressources,
        uint256[] calldata _amounts
    ) public {
        for (uint256 i; i < _planets.length; i++) {
            planetRessources[_planets[i]][_ressources[i]][0] =
                planetRessources[_planets[i]][_ressources[i]][0] +
                _amounts[i];
            ressources[_ressources[i]].token.forceBurn(msg.sender, _amounts[i]);
        }
    }

    function craft(address _ressource, uint256 _quantity) public {}

    function sampleNoise() public pure {}
}
