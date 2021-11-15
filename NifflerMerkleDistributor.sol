/**
 *Submitted for verification at BscScan.com on 2021-11-15
*/

// SPDX-License-Identifier: MIT
pragma solidity =0.6.11;

// Allows anyone to claim a token if they exist in a merkle root.
interface IMerkleDistributor {
    // Returns the address of the token distributed by this contract.
    function token() external view returns (address);
    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);
    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
}

/**
 * @dev These functions deal with verification of Merkle trees (hash trees),
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}


interface IERC20 {
    function decimals() external view returns (uint8);
  /**
   * @dev Returns the amount of tokens in existence.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @dev Returns the amount of tokens owned by `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev Moves `amount` tokens from the caller's account to `recipient`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transfer(address recipient, uint256 amount) external returns (bool);

  /**
   * @dev Returns the remaining number of tokens that `spender` will be
   * allowed to spend on behalf of `owner` through {transferFrom}. This is
   * zero by default.
   *
   * This value changes when {approve} or {transferFrom} are called.
   */
  function allowance(address owner, address spender) external view returns (uint256);

  /**
   * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * IMPORTANT: Beware that changing an allowance with this method brings the risk
   * that someone may use both the old and the new allowance by unfortunate
   * transaction ordering. One possible solution to mitigate this race
   * condition is to first reduce the spender's allowance to 0 and set the
   * desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * Emits an {Approval} event.
   */
  function approve(address spender, uint256 amount) external returns (bool);

  /**
   * @dev Moves `amount` tokens from `sender` to `recipient` using the
   * allowance mechanism. `amount` is then deducted from the caller's
   * allowance.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Emitted when the allowance of a `spender` for an `owner` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);
}


contract NifflerMerkleDistributor is IMerkleDistributor {
    address private admin;
    uint256 public deposit_start_ts;
    uint256 public claim_start_ts;
    address public override token;
    address public raise_token;
    uint256 public price;
    bytes32 public override merkleRoot;
    mapping(address => uint256) private depositInfo;

    constructor() public {
        admin = msg.sender;
    }

    function setAllParam(address token_, address raise_token_, uint256 price_,
        bytes32 merkleRoot_, uint256 deposit_start_ts_, uint256 claim_start_ts_) external {
        require(admin == msg.sender, 'MerkleDistributor: Must be the admin.');
        token = token_;
        raise_token = raise_token_;
        price = price_;
        merkleRoot = merkleRoot_;
        deposit_start_ts = deposit_start_ts_;
        claim_start_ts = claim_start_ts_;
    }

    function getAmountCanBuy(uint256 deposit_amount) public view returns(uint256) {
        uint8 d1 = IERC20(raise_token).decimals();
        uint8 d2 = IERC20(token).decimals();
        uint256 r = deposit_amount * 10000 * (10 ** uint256(d2)) / (10 ** uint256(d1)) / price;
        return r;
    }

    function deposit(uint256 deposit_amount, uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external {
        require(block.timestamp >= deposit_start_ts, 'MerkleDistributor: Deposit not start.');
        require(account == msg.sender, 'MerkleDistributor: Must be the address owner.');
        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');
        require(depositInfo[msg.sender] + deposit_amount <= amount, 'MerkleDistributor: Exceed max amount can buy.');
        require(IERC20(raise_token).transferFrom(msg.sender, address(this), deposit_amount), 'MerkleDistributor: Deposit failed.');
        depositInfo[msg.sender] += deposit_amount;
    }

    function getDepositedAmount(address addr_) public view returns(uint256) {
        return depositInfo[addr_];
    }

    function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(block.timestamp >= claim_start_ts, 'MerkleDistributor: Claim not start.');
        require(account == msg.sender, 'MerkleDistributor: Must be the address owner.');
        require(depositInfo[msg.sender] > 0, 'MerkleDistributor: Deposit amount is zero.');

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');
        uint256 claim_amount = getAmountCanBuy(depositInfo[msg.sender]);
        require(claim_amount > 0, 'MerkleDistributor: available amount is zero.');
        require(IERC20(token).transfer(account, claim_amount), 'MerkleDistributor: Transfer failed.');
        depositInfo[msg.sender] = 0;
        emit Claimed(index, account, claim_amount);
    }

    function withdraw() external {
        require(admin == msg.sender, "MerkleDistributor: Only admin can withdraw.");
        IERC20(raise_token).transfer(admin, IERC20(raise_token).balanceOf(address(this)));
    }

    function withdraw_token_emergency(address token_) external {
        require(admin == msg.sender, "MerkleDistributor: Only admin can withdraw.");
        IERC20(token_).transfer(admin, IERC20(token_).balanceOf(address(this)));
    }
}
