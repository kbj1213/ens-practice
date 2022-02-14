pragma solidity >=0.8.4;

import "./ENS.sol";

//Registrar: subdomain을 할당해주는 컨트랙.
//only_owner modifier 내부의 require 구문을 보면
//currentOwner == address(0x0)이 있는데, 이것이 의미하는 것은 지금 `{rootNode}{label}`의 주인이 없다는 뜻
//currentOwner == msg.sender는 현재 `{rootNode}{label}`의 주인이 있고 컨트랙 호출한 사람이 그 주인이라는 뜻
//둘 중 하나만 성립해도 자격 충족.

//function register 에서 modifier로 only_owner를 갖는다.
//modifier의 조건은
//  1) label.rootNode 의 owner가 0x0일 때 (주인이 없을 때)
//  2) 지금 컨트랙을 호출한 사람이 label.rootNode의 owner일 때
//따라서 현재 특정 label.rootNode 도메인이 비어있으면 누구나 와서 인자로 받은 owner를 label.rootNode의 주인으로 만들 수 있고
//현재 label.rootNode가 owner의 소유라면 owner만이 label.rootNode의 주인를 설정할 수 있다.

/**
 * A registrar that allocates subdomains to the first person to claim them.
 */
contract FIFSRegistrar {
    ENS ens;
    bytes32 rootNode;
    
    modifier only_owner(bytes32 label) {
        address currentOwner = ens.owner(keccak256(abi.encodePacked(rootNode, label)));
        require(currentOwner == address(0x0) || currentOwner == msg.sender);
        _;
    }

    /**
     * Constructor.
     * @param ensAddr The address of the ENS registry.
     * @param node The node that this registrar administers.
     */
    constructor(ENS ensAddr, bytes32 node) public {
        ens = ensAddr;
        rootNode = node;    
    }

    /**
     * Register a name, or change the owner of an existing registration.
     * @param label The hash of the label to register.
     * @param owner The address of the new owner.
     */
    function register(bytes32 label, address owner) public only_owner(label) {
        ens.setSubnodeOwner(rootNode, label, owner);
    }
}
