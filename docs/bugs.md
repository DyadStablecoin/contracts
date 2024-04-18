1) in `addKerosene` it should check the vault licenser if it is licensed
2) in `getKeroseneValue` it should check the vault licenser if it is licensed
3) in `assetPrice` of unbounded it uses the `dyad.totalSupply` of the whole 
   system and not only V2.
