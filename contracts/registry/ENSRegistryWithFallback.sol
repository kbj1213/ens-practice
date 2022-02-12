pragma solidity >=0.8.4;

import "./ENS.sol";
import "./ENSRegistry.sol";

// https://docs.ens.domains/ens-migration-february-2020/technical-description#new-ens-deployment 참고
// ENS가 old에서 한 번 upgrade migration됐음.
// record가 새로 배포된 registry storage에서 발견안되면 fallback registry로 넘어와서 서치함.

// 이런 fallback은 오직 read operations에 대해서만 동작
// 요약하자면, record가 old registry에만 존재하면, 유저들이 새 registry에서 이 record를 변형하는 함수를 call할 수 없음

// example
// 'foo.eth'가 아직 new registry에 없다면 'eth'의 owner는
// 'setSubnodeOwner'나 'setSubnodeRecord'를 call해서 'foo.eth'가 새로 등록되는 도메인인 것처럼 하는 방식으로 이를 만들어야함.

// docs에 나와있는 추가 설명
// .eth .luxe .kred 등과 같은 TLD는 배포 과정에서 migration됨
// .eth의 2차 도메인들 (예를 들면 foo.eth)는 유저들을 위해 자동으로 migration 될 것임.
// subdomain registrar에 의해 관리되는 subdomain들은 유저들을 위해 자동으로 migration 될 것임
// 다른 방법에 의해 만들어진 subdomains는 유저가 직접 migration 해야함
// 

/**
 * The ENS registry contract.
 */
contract ENSRegistryWithFallback is ENSRegistry {

    ENS public old;

    /**
     * @dev Constructs a new ENS registrar.
     */
    constructor(ENS _old) public ENSRegistry() {
        old = _old;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node) public override view returns (address) {
        if (!recordExists(node)) {
            return old.resolver(node);
        }

        return super.resolver(node);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public override view returns (address) {
        if (!recordExists(node)) {
            return old.owner(node);
        }

        return super.owner(node);
    }

    /**
     * @dev Returns the TTL of a node, and any records associated with it.
     * @param node The specified node.
     * @return ttl of the node.
     */
    function ttl(bytes32 node) public override view returns (uint64) {
        if (!recordExists(node)) {
            return old.ttl(node);
        }

        return super.ttl(node);
    }

    function _setOwner(bytes32 node, address owner) internal override {
        address addr = owner;
        if (addr == address(0x0)) {
            addr = address(this);
        }

        super._setOwner(node, addr);
    }
}
