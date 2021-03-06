pragma solidity >=0.8.4;

import "./ENS.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../root/Controllable.sol";

//  function _claimWithResolver
//  1. reverse node가 records_list 어딘가에 있다.
//      1)해당 record의 resolver값이 있는 경우
//          currentResolver가 해당 resolver를 받아옴.
//          지금 인자로 받아온 resolver가 현재 record에 있는 resolveㄱ와 다르다면 newResolver (인자로 받은 resolver)로 record 업데이트
//      2)해당 record의 resolver값이 0x0인 경우 (resolver가 없는 경우)
//          update nono
//  2. reverse node가 record어딘가에 없는 경우 (resolver값이 0x0인 경우)
//      update no

//  function claim(address owner)의 경우
//  _claimWithResolver(msg.sender, owner, address(0x0));를 실행하므로
//  resolver값을 일부러 0x0을 줘서 reverse subdomain의 owner만 바뀌게 만듬.
//  메세지를 보낸 사람의 이더 주소의 addr.reverse 노드의 ownership을 건드림

//  function claimForAddr(address addr, address owner)
//  claim과 거의 같음.
//  차이점은 메세지를 보낸 사람의 이더 주소의 reverse 노드가 아니라
//  특정 addr의 reverse node를 건드림. --> authorized modifier가 붙음

//  function claimWithResolver(address owner, address resolver)
//  메세지 보낸 사람의 이더 주소의 reverse 노드를 건드림.
//  owner뿐만 아니라 resolver주소까지 받아서 record를 새로 갱신함.

//  function claimWithResolverForAddr (address addr, address owner, address resolver)
//  특정 addr의 reverse node를 건드려서 owner와 resolver주소를 갱신.
//  --> authorized modifier가 붙음

//  function setName(string memory name)
//  이 메세지를 보낸 사람의 이더 주소의 reverse 노드를 찾아서
//  owner를 이 컨트랙 주소로, resolver를 defaultResolver로 세팅한 후
//  defaultResolver에서 이 노드에 대해 name을 매칭시켜줌

//  function setNameForAddr(address addr, address owner, string memory name)
//  특정 addr의 reverse node를 찾아서 owner를 이 컨트랙 주소로, resolver를 defaultResolver로 세팅한 후
//  setName 함수와 같이 defaultResolver에서 이 노드에 대해 name 매칭
//  그리고 나서 ensRegistry의 setSubnodeOwner를 받아, 해당 node의 주인을 인자로 받았던 owner로 바꿈 (바로 전에 owner를 이 컨트랙(ReverseRegistrar)으로 바꿔놨기 때문에 가능)


abstract contract NameResolver {
    function setName(bytes32 node, string memory name) public virtual;
}

bytes32 constant lookup = 0x3031323334353637383961626364656600000000000000000000000000000000;

bytes32 constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;
// namehash('addr.reverse')

contract ReverseRegistrar is Ownable, Controllable {
    ENS public ens;
    NameResolver public defaultResolver;

    event ReverseClaimed(address indexed addr, bytes32 indexed node);

    /**
     * @dev Constructor
     * @param ensAddr The address of the ENS registry.
     * @param resolverAddr The address of the default reverse resolver.
     */
    constructor(ENS ensAddr, NameResolver resolverAddr) {
        ens = ensAddr;
        defaultResolver = resolverAddr;

        // Assign ownership of the reverse record to our deployer
        ReverseRegistrar oldRegistrar = ReverseRegistrar(
            ens.owner(ADDR_REVERSE_NODE)
        );
        if (address(oldRegistrar) != address(0x0)) {
            oldRegistrar.claim(msg.sender);
        }
    }

    modifier authorised(address addr) {
        require(
            addr == msg.sender ||
                controllers[msg.sender] ||
                ens.isApprovedForAll(addr, msg.sender) ||
                ownsContract(addr),
            "Caller is not a controller or authorised by address or the address itself"
        );
        _;
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @return The ENS node hash of the reverse record.
     */
    function claim(address owner) public returns (bytes32) {
        return _claimWithResolver(msg.sender, owner, address(0x0));
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param addr The reverse record to set
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @return The ENS node hash of the reverse record.
     */
    function claimForAddr(address addr, address owner)
        public
        authorised(addr)
        returns (bytes32)
    {
        return _claimWithResolver(addr, owner, address(0x0));
    }

    /**
     * @dev Transfers ownership of the reverse ENS record associated with the
     *      calling account.
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The ENS node hash of the reverse record.
     */
    function claimWithResolver(address owner, address resolver)
        public
        returns (bytes32)
    {
        return _claimWithResolver(msg.sender, owner, resolver);
    }

    /**
     * @dev Transfers ownership of the reverse ENS record specified with the
     *      address provided
     * @param addr The reverse record to set
     * @param owner The address to set as the owner of the reverse record in ENS.
     * @param resolver The address of the resolver to set; 0 to leave unchanged.
     * @return The ENS node hash of the reverse record.
     */
    function claimWithResolverForAddr(
        address addr,
        address owner,
        address resolver
    ) public authorised(addr) returns (bytes32) {
        return _claimWithResolver(addr, owner, resolver);
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the calling account. First updates the resolver to the default reverse
     * resolver if necessary.
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setName(string memory name) public returns (bytes32) {
        bytes32 node = _claimWithResolver(
            msg.sender,
            address(this),
            address(defaultResolver)
        );
        defaultResolver.setName(node, name);
        return node;
    }

    /**
     * @dev Sets the `name()` record for the reverse ENS record associated with
     * the account provided. First updates the resolver to the default reverse
     * resolver if necessary.
     * Only callable by controllers and authorised users
     * @param addr The reverse record to set
     * @param owner The owner of the reverse node
     * @param name The name to set for this address.
     * @return The ENS node hash of the reverse record.
     */
    function setNameForAddr(
        address addr,
        address owner,
        string memory name
    ) public authorised(addr) returns (bytes32) {
        bytes32 node = _claimWithResolver(
            addr,
            address(this),
            address(defaultResolver)
        );
        defaultResolver.setName(node, name);
        ens.setSubnodeOwner(ADDR_REVERSE_NODE, sha3HexAddress(addr), owner);
        return node;
    }

    /**
     * @dev Returns the node hash for a given account's reverse records.
     * @param addr The address to hash
     * @return The ENS node hash.
     */
    function node(address addr) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(ADDR_REVERSE_NODE, sha3HexAddress(addr))
            );
    }

    /**
     * @dev An optimised function to compute the sha3 of the lower-case
     *      hexadecimal representation of an Ethereum address.
     * @param addr The address to hash
     * @return ret The SHA3 hash of the lower-case hexadecimal encoding of the
     *         input address.
     */
    function sha3HexAddress(address addr) private pure returns (bytes32 ret) {
        assembly {
            for {
                let i := 40 
            } gt(i, 0) {

            } {
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
                i := sub(i, 1)
                mstore8(i, byte(and(addr, 0xf), lookup))
                addr := div(addr, 0x10)
            }

            ret := keccak256(0, 40)
        }
    }

    /* Internal functions */
    // addr의 reverse node를 찾아 owner와 resolver를 set하는 함수
    // reverse node가 records_list어딘가의 resolver에 이미 있는지 없는지 확인하고 없으면 새로운 resolver를 갱신해서
    // record에 병합하여 setSubnodeRecord실행.
    function _claimWithResolver(
        address addr,
        address owner,
        address resolver
    ) internal returns (bytes32) {
        bytes32 label = sha3HexAddress(addr);   //addr을 sha3값으로 변환
        bytes32 node = keccak256(abi.encodePacked(ADDR_REVERSE_NODE, label));   // {addr}{addr.reverse} 의 namehash가 input으로 들어가는 상황
        address currentResolver = ens.resolver(node);   
        bool shouldUpdateResolver = (resolver != address(0x0) &&
            resolver != currentResolver);
        address newResolver = shouldUpdateResolver ? resolver : currentResolver;

        ens.setSubnodeRecord(ADDR_REVERSE_NODE, label, owner, newResolver, 0);

        emit ReverseClaimed(addr, node);

        return node;
    }

    function ownsContract(address addr) internal view returns (bool) {
        try Ownable(addr).owner() returns (address owner) {
            return owner == msg.sender;
        } catch {
            return false;
        }
    }
}
