1) in `addKerosene` it should check the vault licenser if it is licensed
2) in `getKeroseneValue` it should check the vault licenser if it is licensed
3) in `assetPrice` of unbounded it uses the `dyad.totalSupply` of the whole 
4) in `liquidate` only non-kerosene assets are transfered
5) in `assetPrice` put in require so tvl > dyad.totalSupply()
6) in `add` any vault can be added
7) in `deposit` only by dnft owner because ddos
8) `withdraw` + `deposit` in same block seems to be a problem
9) in `withdraw` we need to check `getNonKeroseneValue` after withdrawing
