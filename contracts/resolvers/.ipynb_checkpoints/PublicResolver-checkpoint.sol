// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import "../registry/ENS.sol";
import "./profiles/ABIResolver.sol";
import "./profiles/AddrResolver.sol";
import "./profiles/ContentHashResolver.sol";
import "./profiles/DNSResolver.sol";
import "./profiles/InterfaceResolver.sol";
import "./profiles/NameResolver.sol";
import "./profiles/PubkeyResolver.sol";
import "./profiles/TextResolver.sol";
import "./Multicallable.sol";

//mapping(address => mapping(address => bool)) private _operatorApprovals;
//         소유자            operator   허가여부

//------------- function supportsInterface(bytes4 interfaceID) --------------
//type(IMulticallable).interfaceId 의 의미.
//컨트랙트 내부의 IMulticallable method의 selector 역할.

//----function isAuthorised(bytes32 node) internal override view returns(bool)----
//isAuthorised는 각종 resolver들이 상속받는 ResolverBase라는 abstract contract에 declaration만 있음.
//특정 node의 owner가 지갑주소일 수도 있고 nameWrapper 컨트랙일 수도 있음.
//nameWrapper가 owner라면 nameWrapper로 찾아가서 이 node의 주인인 NFT토큰을 찾고 그 NFT의 owner를 갖고옴

//----function ownerOf(uint256 id) external view returns (address)----
//Namewrapper이 상속받는 ERC1155Fuse 컨트랙에 선언돼있음.
//Token의 id를 받아서 토큰들 중 해당 id를 가진 token의 주소를 반환해줌. (이게 owner)

//여기 PublicResolver에도 mapping(address => mapping(address => bool)) private _operatorApprovals가 있고
//ENSRegistry에도 mapping (address => mapping(address => bool)) operators가 있는데,
//두 컨트랙 모두 function setApprovalForAll(address operator, bool approved)를 갖고 있음.
//서로 독립적인 것인지, 프론트 단에서 엮어서 한꺼번에 동기화를 시켜주는건지 아직 모르겠음.


interface INameWrapper {
    function ownerOf(uint256 id) external view returns (address);
}

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its
 * address.
 */
contract PublicResolver is Multicallable, ABIResolver, AddrResolver, ContentHashResolver, DNSResolver, InterfaceResolver, NameResolver, PubkeyResolver, TextResolver {
    ENS ens;
    INameWrapper nameWrapper;

    /**
     * A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Logged when an operator is added or removed.
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    constructor(ENS _ens, INameWrapper wrapperAddress){
        ens = _ens;
        nameWrapper = wrapperAddress;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external{
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isAuthorised(bytes32 node) internal override view returns(bool) {
        address owner = ens.owner(node);
        if(owner == address(nameWrapper) ){
            owner = nameWrapper.ownerOf(uint256(node));
        }
        return owner == msg.sender || isApprovedForAll(owner, msg.sender);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view returns (bool){
        return _operatorApprovals[account][operator];
    }

    function supportsInterface(bytes4 interfaceID) public override(Multicallable, ABIResolver, AddrResolver, ContentHashResolver, DNSResolver, InterfaceResolver, NameResolver, PubkeyResolver, TextResolver) pure returns(bool) {
        return interfaceID == type(IMulticallable).interfaceId || super.supportsInterface(interfaceID);
    }
}
