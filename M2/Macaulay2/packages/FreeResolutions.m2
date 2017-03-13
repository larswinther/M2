newPackage(
        "FreeResolutions",
        Version => "0.1", 
        Date => "Oct 2014",
        Authors => {{Name => "Mike Stillman", 
                  Email => "", 
                  HomePage => ""}},
        Headline => "Experimental versions of free resolutions",
        DebuggingMode => true
        )

export {
    -- svd more complexes code
    "constantStrand",
    "constantStrands",
    "laplacians",
    "getNonminimalRes",
    "degreeZeroMatrix",
    "minimizeBetti",
    "SVDComplex",
    "SVDHomology",
    "SVDBetti",
    "Projection",
    "Laplacian",
    "newChainComplexMap",
    "numericRank",
    "checkSVDComplex",
    -- top level resolution experiments
    "ModuleMonomial",
    "component",
    "monomial",
    "moduleMonomial",
    "Polynomial",
    "PolynomialList",
    "makeFrameFromPolynomials",
    "makeResolutionData",
    "findModuleMonomial",
    "monomialLookup",
    "nextFrame",
    "makeFrames",
    "getImage",
    "ResolutionData",
    "LeadTerm",
    "Coefficients",
    "DescendentRange",
    "getMatrix",
    -- examples
    "AGRExample"
    }

protect Frame
protect RowList
protect MonomialHashTable
protect SPairMatrix

component = method()
monomial = method()
moduleMonomial = method()

ModuleMonomial = new Type of List -- (monomial, component#)
Polynomial = new Type of MutableHashTable -- has
  -- components: LeadTerm, Monomials, Coefficients, Degree, DescendentRange
  --  "Coefficients", "Monomials", "DescendentRange" can all be missing
  -- and in fact the main algorithm's duty is to populate Coefficients, Monomials.
  -- DescendentRange: list of two integer indices into the next PolynomialList if any.
  -- Only set once the next frame has been constructed.

moduleMonomial(RingElement, ZZ) := (f, i) -> new ModuleMonomial from {f,i}
component ModuleMonomial := (m) -> m#1
monomial ModuleMonomial := (m) -> m#0
toString ModuleMonomial := (m) -> toString {m#0, m#1}
-- The following structure contains the data we need to compute one
-- matrix in the non-minimal resolution It contains also the variables
-- needed in the generation of the matrices over the base field kk.
ResolutionData = new Type of MutableHashTable

-- A list of:
--   polynomials forming a GB.
-- OR: partial information, such as the lead term only
-- Format:
--   each polynomial is a pair of lists:
--    a. list of ModuleMonomial's
--    b. the coefficients of each monomial
-- The first monomial is the lead term
-- The first coefficient is ONE (this is a MONIC GB).
PolynomialList = new Type of MutableList

leadTerm PolynomialList := (P) -> (
    for f from 0 to #P-1 list P#f . LeadTerm
    )

net PolynomialList := (P) -> (
    netList for f from 0 to #P-1 list (
        entry := P#f;
        monomstr := if not entry.?Monomials then "(no poly)"
          else (
              monoms := entry.Monomials;
              if #monoms > 5 then (toString(#monoms)|" terms")
              else monoms/toString
              );
        coeffstr := if not entry.?Coefficients then "" else (
                    coeffs := entry.Coefficients;
                    if #coeffs > 5 then ""
                    else coeffs/toString);
        desc := if entry.?DescendentRange then (
            toString (entry.DescendentRange#0)
                    | ".." 
                    | toString (entry.DescendentRange#1-1)
             ) else "--";
        {
        f,
        entry.LeadTerm#0, 
        entry.LeadTerm#1, 
        entry.Degree,
        desc,
        monomstr,
        coeffstr
        }
    ))

makeFrameFromPolynomials = method(TypicalValue=>Sequence) -- of two PolynomialList's
makeFrameFromPolynomials List := (L) -> (
    assert(#L > 0);
    R := ring L#0; -- better not be the empty list!
    result0 := new PolynomialList;
    result0#0 = new MutableHashTable from {
        LeadTerm => moduleMonomial(1_R, 0),
        Monomials => {1_R},
        Coefficients => {1_(coefficientRing R)},
        DescendentRange => {0,#L},
        Degree => 0
        };
    result := new PolynomialList;
    for i from 0 to #L - 1 do (
        ts := terms L#i;
        poly := transpose for t in ts list 
            {moduleMonomial(leadMonomial t, 0), leadCoefficient t};
        result#i = new MutableHashTable from {
            LeadTerm => moduleMonomial(leadMonomial L#i, 0),
            Monomials => poly#0,
            Coefficients => poly#1,
            Degree => first degree L#i
            }
        );
    (result0, result)
    )

nextFrame = method()
nextFrame(PolynomialList,PolynomialList) := (P0,P1) -> (
    -- returns either a PolynomialList P2 for the next level,
    -- or null, if there are no new elements at that level.
    -- Modifies P1, by adding the "DescendentRange" field to each polynomial
    --   that occur as lead term components at the next level.
    P2 := new PolynomialList;
    nextindex := 0;
    for i from 0 to #P0-1 do (
        if P0#i .? DescendentRange then (
            (lo,hi) := toSequence (P0#i . DescendentRange);
            for j from lo+1 to hi-1 do (
                firstindex := nextindex;
                -- idea here: compute the mingens of the ideal quotient
                -- (f_lo, ..., f_(j-1)) : f_j.
                -- Add each of these to the frame P2.
                thisI := monomialIdeal for ell from lo to j-1 list 
                    monomial P1#ell.LeadTerm;
                nextI := thisI : (monomial P1#j.LeadTerm);
                for m in nextI_* do (
                    P2#nextindex = new MutableHashTable from {
                        LeadTerm => moduleMonomial(m, j),
                        Degree => first degree m + P1#j.Degree
                        };
                    nextindex = nextindex+1;
                    );
                P1#j.DescendentRange = {firstindex, nextindex};
                );
            )    
        );
    P2
    )

makeFrames = method()
makeFrames(PolynomialList, PolynomialList) := (P0,P1) -> (
    result := new MutableList from {P0,P1};
    while #result#-1 > 0 do (
        lev := #result-1;
        elapsedTime result#(lev+1) = nextFrame(result#(lev-1), result#lev);
        );
    toList result
    )

makeResolutionData = method()
makeResolutionData(List) := (Ps) -> (
    new ResolutionData from {
        Frame => Ps
        }
    )
ring ResolutionData := (D) -> ring(D.Frame#0#0 . LeadTerm#0)
degrees(ZZ, ResolutionData) := (level, D) -> (
    if level >= #D.Frame then {} else (
        (toList D.Frame#level) / (x -> x.Degree) // unique // sort
    ))
setNextMatrix = method()
setNextMatrix ResolutionData := (D) -> (
    D.RowList = new MutableList;
    D.MonomialHashTable = new MutableHashTable;
    )

monomialLookup = method()
processMonomial = method()
processRow = method()
findModuleMonomial = method()

findModuleMonomial(
    PolynomialList,
    PolynomialList, 
    ModuleMonomial)  := (P0,P1,mon) -> (
    -- mon is a monomial at level P1
    -- find the (canonical) monomial at level P2 which maps to mon (if it exists)
    -- first find the locations
    (m, comp) := toSequence mon;
    if P0#comp.?DescendentRange then (
        (start,end) := toSequence(P0#comp . DescendentRange);
        for j from start to end-1 do (
            n := monomial (P1#j . LeadTerm);
            if m % n == 0 then (
                -- We got one!
                m1 := m // n;
                return moduleMonomial(m1, j);
                );
            );
        );
    null
    )

monomialLookup(ModuleMonomial, ZZ, ResolutionData) := (mon, lev, D) -> (
    -- returns: either an index or null
    -- the index will be into the matrix being constructed.
    -- mon: monomial at level 'lev' (when we are constructing lev+1)
    -- side effects:
    --   mon might be added to a hash table
    --   a Modulemonomial at the next level might be added to the rowList
    --   the internal 'nextIndex' number might be incremented.
    H := D.MonomialHashTable;
    L := D.RowList;
    if not H#?mon then (
        -- need to add mon to H
        -- need to find the corresponding row
        --   and add it to L, assuming mon is in the submodule of initial terms
        val := findModuleMonomial(D.Frame#(lev-1), D.Frame#lev, mon);
        if val === null then (
            H#mon = null;
            return null;
            );
        -- otherwise 'val' is a ModuleMonomial at level 'lev+1'.
        H#mon = #L;
        L#(#L) = val;
        );
    H#mon    
    )

getImage = method()
getImage(ModuleMonomial, ZZ, ResolutionData) := (mon, level, D) -> (
    (m, comp) := toSequence mon;
    prev := D.Frame#(level-1)#comp;
    moduleMonomial(m * prev.LeadTerm#0, prev.LeadTerm#1)
    )

processRow(ModuleMonomial, ZZ, ResolutionData) := (mon,lev,D) -> (
    (m,comp) := toSequence mon;
    thiscomp := D.Frame#(lev-1)#comp;
    (monoms,coeffs) := if thiscomp.?Monomials then (
                (for f in thiscomp.Monomials list
                    monomialLookup(moduleMonomial(m*f#0, f#1), lev-1, D),
                 thiscomp.Coefficients)
            ) else (
                ({ monomialLookup(thiscomp.LeadTerm, lev-1, D) },
                 { 1_(coefficientRing ring D) })
            );
   (monoms, coeffs)
   )

makeMatrix = method()
makeMatrix(ZZ, ZZ, ResolutionData) := (lev, deg, D) -> (
    kk := coefficientRing ring D;
    -- step 0: initialize matrix data in D
    setNextMatrix D;    
    -- step 1: loop through all "spairs" in D.Frame#lev, and call monomialLookup on them
    thesepairs := positions(D.Frame#lev, t -> t.Degree == deg);
    elapsedTime spairs := for i in thesepairs list (
            t := D.Frame#lev#i;
            processRow(t.LeadTerm, lev, D)
            );
    -- step 2: loop through all elements of RowList, do the same, until at end of liast
    r := 0;
    elapsedTime rows := while r < #D.RowList list (
        -- these will have degree 'deg'
        thisrow := processRow(D.RowList#r, lev, D);
        r = r+1;
        thisrow
        );
    -- step 3: at this point, we are ready to construct the matrices, so initialize both
    --   step 3A, optimized: sort the monomials (optional, but probably a good idea?)
    D.Matrix = mutableMatrix(coefficientRing ring D, # D.RowList, #D.RowList);
    D.SPairMatrix = mutableMatrix(coefficientRing ring D, #D.RowList, #thesepairs);
    -- step 4: construct the two matrices
    -- step 4A: construct D.Matrix
    nentries := 0;
    elapsedTime for i from 0 to #rows-1 do (
        (monoms, coeffs) := rows#i;
        for j from 0 to #monoms-1 do
            if monoms#j =!= null then (
                D.Matrix_(monoms#j,i) = coeffs#j;
                nentries = nentries+1;
                );
        );
    << "# of entries in " << numRows D.Matrix << " by " << numRows D.Matrix << " is " << nentries << endl;
    -- step 4B: construct D.SPairMatrix
    nentries = 0;
    elapsedTime for i from 0 to #spairs-1 do (
        (monoms, coeffs) := spairs#i;
        for j from 0 to #monoms-1 do
            if monoms#j =!= null then (
                D.SPairMatrix_(monoms#j,i) = coeffs#j;
                nentries = nentries + 1;
                );
        );
    << "# of entries in " << numRows D.Matrix << " by " << numColumns D.SPairMatrix << " is " << nentries << endl;    
    -- step 5: solve
    << "matrix sizes: " << numColumns D.Matrix << " and " << numColumns D.SPairMatrix << endl;
    elapsedTime X := solve(D.Matrix, D.SPairMatrix);
    -- step 6: put the polynomials back into D.Frame#lev
    --   each spair needs the original lead term.
    elapsedTime for i from 0 to #thesepairs-1 do (
        t := D.Frame#lev#(thesepairs#i);
        -- fill in t.Coefficients, t.Monomials
        t.Monomials = {t.LeadTerm};
        t.Coefficients = {1_kk};
        for j from 0 to #D.RowList-1 do (
            if X_(j,i) != 0 then (
                t.Monomials = append(t.Monomials, D.RowList#j);
                t.Coefficients = append(t.Coefficients, - X_(j,i));
                );
            );
        );
    )

getMatrix = method()
getMatrix(ZZ, ResolutionData) := (level, D) -> (
    ncols := #D.Frame#level;
    nrows := #D.Frame#(level-1);
    M := mutableMatrix(ring D, nrows, ncols);
    for c from 0 to ncols-1 do (
        t := D.Frame#level#c;
        if not t.?Monomials then 
            M_(t.LeadTerm#1, c) = t.LeadTerm#0
        else for i from 0 to #t.Monomials-1 do (
            mon := t.Monomials#i;
            coeff := t.Coefficients#i;
            M_(mon#1, c) = M_(mon#1, c) + coeff * mon#0
            );
        );
    M
    )

getMatrix(ZZ, ZZ, ZZ, ResolutionData) := (level, srcdeg, targetdeg, D) -> (
    cols := positions(D.Frame#level, t -> t.Degree == srcdeg);
    rows := positions(D.Frame#(level-1), t -> t.Degree == targetdeg);
    inv'cols := new MutableList from #cols:null;
    for c from 0 to #cols-1 do inv'cols#(cols#c) = c;
    inv'rows := new MutableHashTable;
    for r from 0 to #rows-1 do inv'rows#(rows#r) = r;
    M := mutableMatrix(ring D, #rows, #cols);
    for c from 0 to #cols-1 do (
        t := D.Frame#level#(cols#c);
        if not t.?Monomials then (
            if rows#?(t.LeadTerm#1) then 
            M_(rows#(t.LeadTerm#1), c) = t.LeadTerm#0
        ) else for i from 0 to #t.Monomials-1 do (
            mon := t.Monomials#i;
            coeff := t.Coefficients#i;
            if inv'rows#?(mon#1) then (
                cp := inv'rows#(mon#1);
                M_(cp, c) = M_(cp, c) + coeff * mon#0
            );
        ));
    M
    )

betti(ResolutionData) := opts -> (D) -> (
    new BettiTally from flatten for level from 0 to #D.Frame -1 list (
        degs := degrees(level,D);
        for d in degs list (
            nindegree := # select(D.Frame#level, t -> t.Degree == d);
            (level, {d}, d) => nindegree
            )
        )
    )


-----------------------------------------------
-- Code for SVD of a complex ------------------
-----------------------------------------------
debug Core
constantStrand = method()
constantStrand(ChainComplex, Ring, ZZ) := (C, kk, deg) -> (
    -- base ring of C should be QQ
    if coefficientRing ring C =!= QQ then error "ring of the complex must be a polynomial ring over QQ";
    -- assumption: we are resolving an ideal, or at least all gens occur in degree >= 0.
    len := length C;
    reg := regularity C;
    --if deg <= 2 or deg > len+reg then error("degree should be in the range 2.."|len+reg);
    chainComplex for lev from 1 to len list (
        matrix map(kk, rawResolutionGetMutableMatrix2B(C.Resolution.RawComputation, raw kk, deg,lev))
        )
    )    

constantStrands = method()
constantStrands(ChainComplex, Ring) := (C, kk) -> (
    -- base ring of C should be QQ
    if coefficientRing ring C =!= QQ then error "ring of the complex must be a polynomial ring over QQ";
    -- assumption: we are resolving an ideal, or at least all gens occur in degree >= 0.
    len := length C;
    reg := regularity C;
    hashTable for deg from 0 to len+reg list (
        D := constantStrand(C,kk,deg);
        if D == 0 then continue else deg => D
        )
    )

laplacians = method()
laplacians ChainComplex := (L) -> (
      rg := select(spots L, i -> L_i != 0);
      for i in rg list ((transpose L.dd_(i)) *  L.dd_(i) + (L.dd_(i+1) * (transpose L.dd_(i+1))))
      )

getNonminimalRes = method()
getNonminimalRes(ChainComplex, Ring) := (C, R) -> (
    -- if C was created using FastNonminimal=>true, then returns the nonmimal complex.
    -- if ring C is not QQ, this should be exactly C (with C.dd set).
    -- if ring C is QQ, then R must be either RR_53 (monoid ring C), or (ZZ/p)(monoid ring C), where p is the prime used to
    --  construct the resolution (later, there might be several such primes, and also we can
    --  query and get them.  But not yet.)
    rawC := C.Resolution.RawComputation;
    result := new MutableList;
    for i from 0 to length C - 1 do (
      result#i = matrix map(R, rawResolutionGetMutableMatrixB(rawC, raw R, i+1));
      if i > 0 then result#i = map(source result#(i-1),,result#i);
      );
    chainComplex toList result
    )

degreeZeroMatrix = method()
degreeZeroMatrix(ChainComplex, ZZ, ZZ) := (C, slanteddeg, level) -> (
    if ring C === QQ then error "need to provide a target coefficient ring, QQ is not allowed";
    kk := coefficientRing ring C;
    rawC := C.Resolution.RawComputation;
    matrix map(coefficientRing ring C, rawResolutionGetMatrix2(rawC, level, slanteddeg+level))
    )

degreeZeroMatrix(ChainComplex, Ring, ZZ, ZZ) := (C, kk, slanteddeg, level) -> (
    if kk =!= QQ then degreeZeroMatrix(C,slanteddeg, level)
    else (
        rawC := C.Resolution.RawComputation;
        matrix map(kk, rawResolutionGetMutableMatrix2B(rawC, raw kk, slanteddeg+level,level))
        )
    )

-- given a mutable Betti table, find the spots (deg,lev) where there are degree 0 maps.
degzero = (B) -> (
    degsB := select(keys B, (lev,deglist,deg) -> B#?(lev-1,deglist,deg));
    degsB = degsB/(x -> (x#0, x#2-x#0));
    degsB = degsB/reverse//sort -- (deg,lev) pairs.
    )  

numericRank = method()
numericRank Matrix := (M) -> (
    if ring M =!= RR_53 then error "expected real matrix";
    (sigma, U, Vt) := SVD M;
    pos := select(#sigma-1, i -> sigma#i/sigma#(i+1) > 1e4);
    if #pos === 0 then #sigma else (min pos)+1
    --# select(sigma, s -> s > 1e-10)
    )

minimizeBetti = method()
minimizeBetti(ChainComplex, Ring) := (C, kk) -> (
    B := betti C;
    mB := new MutableHashTable from B;
    rk := if kk =!= RR_53 then rank else numericRank;
    for x in degzero B do (
      (sdeg,lev) := x;
      m := degreeZeroMatrix(C, kk, sdeg, lev);
      r := rk m;
      << "doing " << (sdeg, lev) << " rank[" << numRows m << "," << numColumns m << "] = " << r << endl;
      mB#(lev,{lev+sdeg},lev+sdeg) = mB#(lev,{lev+sdeg},lev+sdeg) - r;
      mB#(lev-1,{lev+sdeg},lev+sdeg) = mB#(lev-1,{lev+sdeg},lev+sdeg) - r;
      if debugLevel > 2 then << "new betti = " << betti mB << endl;
      );
  new BettiTally from mB
  )

chainComplex(HashTable) := (maps) -> (
    -- maps should be a HashTable with keys integers.  values are maps at that spot.
    rgs := (values maps)/ring//unique;
    if #rgs != 1 then error "expected matrices over the same ring";
    R := rgs#0;
    C := new ChainComplex;
    C.ring = R;
    for i in keys maps do (
        f := maps#i;
        F := source f;
        G := target f;
        if C#?i then (if C#i =!= F then error("different modules at index "|i))
        else C#i = F;
        if C#?(i-1) then (if C#(i-1) =!= G then error("different modules at index "|i-1))
        else C#(i-1) = G;
        );
    C.dd.cache = new CacheTable;
    lo := min keys maps - 1;
    hi := max keys maps;
    for i from lo+1 to hi do C.dd#i = if maps#?i then maps#i else map(C_i, C_(i-1), 0);
    C
    )

newChainComplexMap = method()
newChainComplexMap(ChainComplex, ChainComplex, HashTable) := (tar,src,maps) -> (
     f := new ChainComplexMap;
     f.cache = new CacheTable;
     f.source = src;
     f.target = tar;
     f.degree = 0;
     goodspots := select(spots src, i -> src_i != 0);
     scan(goodspots, i -> f#i = if maps#?i then maps#i else map(tar_i, src_i, 0));
     f
    )
SVDComplex = method(Options => {
        Strategy => Projection -- other choice: Laplacian
        }
    )

SVDComplex ChainComplex := opts -> (C) -> (
    if ring C =!= RR_53 then error "excepted chain complex over the reals RR_53";
    goodspots := select(spots C, i -> C_i != 0);
    if #goodspots === 1 then return (id_C, hashTable {goodspots#0 => rank C_(goodspots#0)}, hashTable{});
    (lo, hi) := (min goodspots, max goodspots);
    Cranks := hashTable for ell from lo to hi list ell => rank C_ell;
    rks := new MutableList; -- from lo to hi, these are the ranks of C.dd_ell, with rks#lo = 0.
    hs := new MutableHashTable; -- lo..hi, rank of homology at that step.
    Sigmas := new MutableList; -- the singular values in the SVD complex, indexed lo+1..hi
    Orthos := new MutableHashTable; -- the orthog matrices of the SVD complex, indexed lo..hi
    smallestSing := new MutableHashTable;
    rks#lo = 0;
    sigma1 := null;
    U := null;
    Vt := null;
    if opts.Strategy == symbol Projection then (
        P0 := mutableIdentity(ring C, rank C_lo); -- last projector matrix constructed
        Q0 := mutableMatrix(ring C, 0, Cranks#lo);
        for ell from lo+1 to hi do (
            m1 := P0 * (mutableMatrix C.dd_ell); -- crashes if mutable matrices??
            (sigma1, U, Vt) = SVD m1;
            sigma1 = flatten entries sigma1;
            Sigmas#ell = sigma1;
            -- TODO: the following line needs to be un-hardcoded!!
            rks#ell = # select(sigma1, x -> x > 1e-10);
            smallestSing#ell = sigma1#(rks#ell-1);
            hs#(ell-1) = Cranks#(ell-1) - rks#(ell-1) - rks#ell;
            -- For the vertical map, we need to combine the 2 parts of U, and the remaining part of the map from before
            ortho1 := (transpose U) * P0;
            Orthos#(ell-1) = matrix{{matrix Q0},{matrix ortho1}};
            -- now split Vt into 2 parts.
            P0 = Vt^(toList(rks#ell..numRows Vt-1));
            Q0 = Vt^(toList(0..rks#ell-1));
            );
        -- Now create the Sigma matrices
        Orthos#hi = matrix Vt;
        hs#hi = Cranks#hi - rks#hi;
        SigmaMatrices := hashTable for ell from lo+1 to hi list ell => (
            m := mutableMatrix(RR_53, Cranks#(ell-1), Cranks#ell);
            for i from 0 to rks#ell-1 do m_(rks#(ell-1)+i, i) = Sigmas#ell#i;
            matrix m -- TODO: make this via diagonal matrices and block matrices.
            );
        targetComplex := (chainComplex SigmaMatrices);
        result := newChainComplexMap(targetComplex, C, new HashTable from Orthos);
        return (result, new HashTable from hs, new HashTable from smallestSing);
        );
    if opts.Strategy == symbol Laplacian then (
        );
    error "expected Strategy=>Projection or Strategy=>Laplacian"
    )

SVDHomology = method (Options => options SVDComplex)
SVDHomology ChainComplex := opts -> (C) -> (
    -- returns a hash table of the ranks of the homology of C
    if ring C =!= RR_53 then error "excepted chain complex over the reals RR_53";
    goodspots := select(spots C, i -> C_i != 0);
    if #goodspots === 1 then return (hashTable {goodspots#0 => rank C_(goodspots#0)}, hashTable{});
    (lo, hi) := (min goodspots, max goodspots);
    Cranks := hashTable for ell from lo to hi list ell => rank C_ell;
    rks := new MutableList; -- from lo to hi, these are the ranks of C.dd_ell, with rks#lo = 0.
    hs := new MutableHashTable; -- lo..hi, rank of homology at that step.
    smallestSing := new MutableHashTable;
    rks#lo = 0;
    sigma1 := null;
    U := null;
    Vt := null;
    if opts.Strategy == symbol Projection then (
        P0 := mutableIdentity(ring C, rank C_lo); -- last projector matrix constructed
        for ell from lo+1 to hi do (
            m1 := P0 * (mutableMatrix C.dd_ell); -- crashes if mutable matrices??
            (sigma1, U, Vt) = SVD m1;
            sigma1 = flatten entries sigma1;
            -- TODO: the following line needs to be un-hardcoded!!
            pos := select(#sigma1-1, i -> sigma1#i/sigma1#(i+1) > 1e4);
            rks#ell = if #pos === 0 then #sigma1 else (min pos)+1;
            --remove?-- rks#ell = # select(sigma1, x -> x > 1e-10);
            smallestSing#ell = (sigma1#(rks#ell-1), if rks#ell < #sigma1-1 then sigma1#(rks#ell) else null);
            hs#(ell-1) = Cranks#(ell-1) - rks#(ell-1) - rks#ell;
            -- now split Vt into 2 parts.
            P0 = Vt^(toList(rks#ell..numRows Vt-1));
            );
        hs#hi = Cranks#hi - rks#hi;
        return (new HashTable from hs, new HashTable from smallestSing);
        );
    if opts.Strategy == symbol Laplacian then (
        );
    error "expected Strategy=>Projection or Strategy=>Laplacian"
    )

toBetti = method()
toBetti(ZZ, HashTable) := (deg, H) -> (
      new BettiTally from for k in keys H list (k, {deg}, deg) => H#k
      )

SVDBetti = method()
SVDBetti ChainComplex := (C) -> (
    if coefficientRing ring C =!= QQ then error "expected FastNonminimal resolution over QQ"; 
    Ls := constantStrands(C,RR_53);
    H := hashTable for i in keys Ls list i => SVDHomology Ls#i;
    H2 := hashTable for i in keys H list i => last H#i;
    << "singular values: " << H2 << endl;
    sum for i in keys H list toBetti(i, first H#i)
    )
debug Core  
maxEntry = method()
maxEntry(Matrix) := (m) -> (flatten entries m)/abs//max
maxEntry(ChainComplexMap) := (F) -> max for m in spots F list maxEntry(F_m)
checkSVDComplex = (C, Fhs) -> (
    -- routine to find the smallest errors which occur.
    -- where here (F,hs) = SVDComplex C, C is a complex over RR_53.
    (F,hs, minsing) := Fhs;
    debug Core;
    tar2 := (target F).dd^2;
    src2 := (source F).dd^2;
    val1 := maxEntry tar2;
    val2 := maxEntry src2;
    vals3 := for m in spots F list (flatten entries (((transpose F_m) * F_m) - id_(source F_m)))/abs//max;
    vals4 := for i in spots F list (
        m := (target F).dd_i * F_i - F_(i-1) * (source F).dd_i;
        (flatten entries m)/abs//max
        );
    vals5 := for i in spots F list (
        m := (C.dd_i - ((transpose F_(i-1)) * (target F).dd_i * F_i));
        (flatten entries m)/abs//max
        );
    (val1, val2, vals3, vals4, vals5)
    )
-- TODO for free res stuff with Frank:
-- add QR
-- make sure code doesn't crash when doing minimalBetti over QQ...
-- allow choice of ZZ/p?
-- 
TEST ///
  -- warning: this currently requires test code on res2017 branch.
  -- XXXX
restart
  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"
  R = QQ[a..d]
  F = randomForm(3, R)
  I = ideal fromDual matrix{{F}}
  C = res(I, FastNonminimal=>true)

  Rp = (ZZ/32003)(monoid R)
  R0 = (RR_53) (monoid R)
  Ls = constantStrands(C,RR_53)  
  L = Ls#3
  Lp = laplacians L
  Lp/eigenvalues
  Lp/SVD/first
  
  Cp = getNonminimalRes(C, Rp)
  C0 = getNonminimalRes(C, R0)
  Cp.dd^2
  C0.dd^2
  -- lcm of lead term entries: 8902598454
  -- want to solve x = y/8902598454^2, where y is an integer, and we know x to double precision
  --  and we know x mod 32003.
  -- example: 
  cf = leadCoefficient ((C0.dd_2)_(9,8))
  -- .293215710985088
  leadCoefficient ((Cp.dd_2)_(9,8))
  -- -10338
  -- what is y? (x mod p) = (y mod p)/(lcm mod p)^2
  kk = coefficientRing Rp
  (-10338_kk) / (8902598454_kk)^2
  -- -391...
  (-391 + 32003*k) / 8902598454^2 == .293215710985088
  (cf * 8902598454^2 + 391)/32003.0
  y = 726156310379351
  (y+0.0)/8902598454^2
  oo * 1_kk
///

TEST ///
  -- warning: this currently requires test code on res2017 branch.
restart
  -- YYYYY

  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"
  R = QQ[a..f]
  deg = 6
  nextra = 10
  nextra = 20
  nextra = 30
  --F = randomForm(deg, R)
  setRandomSeed "1000"
   F = sum(gens R, x -> x^deg) + sum(nextra, i -> (randomForm(1,R))^deg);
elapsedTime  I = ideal fromDual matrix{{F}};
  C = res(I, FastNonminimal=>true)

  Rp = (ZZ/32003)(monoid R)
  R0 = (RR_53) (monoid R)
  minimalBetti sub(I, Rp)
  SVDBetti C  

  betti C
  Ls = constantStrands(C,RR_53)  
  Lp = constantStrands(C,ZZ/32003)  
  D = Ls#7
  
  (F, hs, minsing) = SVDComplex D;
  (hs, minsing) = SVDHomology D;
  hs, minsing
  numericRank D.dd_4

  elapsedTime SVDComplex Ls_4;
  elapsedTime SVDComplex Ls_5;
  last oo

  hashTable for k in keys Ls list (k => betti Ls#k)
  sumBetti = method()
  sumBetti HashTable := H -> (
      for k in keys H list (betti H#k)(-k)
      )

  elapsedTime hashTable for i in keys Ls list i => SVDComplex Ls#i;
  
  elapsedTime hashTable for i in keys Ls list i => toBetti(i, first SVDHomology Ls#i);

      
  for i from 0 to #Ls-1 list 
    max flatten checkSVDComplex(Ls_i, SVDComplex Ls_i)

  hashTable for i from 0 to #Ls-1 list 
    i => last SVDComplex Ls_i

  ------ end of example above
    
  debug Core
  kk = ZZp(32003, Strategy=>"Flint")
  Rp = kk(monoid R)
  R0 = (RR_53) (monoid R)
  Cp = getNonminimalRes(C,Rp)
  C0 = getNonminimalRes(C,R0)

  minimizeBetti(C, kk)
  minimizeBetti(C, RR_53)

  Ip = sub(I,Rp);
  minimalBetti Ip

  Lps = constantStrands(C,kk)
  netList oo
  L = Ls_3
  Lp = laplacians L;
  --Lp/eigenvalues

  SVDComplex L
  
  -- compute using projection method the SVD of the complex L
  L.dd_2
  (sigma, U1, V1t) = SVD mutableMatrix L.dd_2
  sigma
  
  betti U1
  betti V1t
  M = mutableMatrix L.dd_2
  sigma1 = mutableMatrix diagonalMatrix matrix sigma
  sigma1 = flatten entries sigma
  sigmaplus = mutableMatrix(RR_53, 75, 5)
  for i from 0 to 4 do sigmaplus_(i,i) = 1/sigma1#i
  sigmaplus
  Mplus = (transpose V1t) * sigmaplus * (transpose U1)
  pkerM = submatrix(V1t, 5..74,);
  M2 = pkerM * mutableMatrix(L.dd_3);
  (sigma2,U2,V2t) = SVD M2  
  sigma2 = flatten entries sigma2
  nonzerosing = position(0..#sigma2-2, i -> (sigma2#(i+1)/sigma2#i < 1.0e-10))
  pkerM2 = submatrix(V2t, nonzerosing+1 .. numRows V2t-1,)  
  sigma2_{0..49}
  sigma2_50  
  M3 = pkerM2 * mutableMatrix(L.dd_4)  ;
  (sigma3,U3,V3t) = SVD M3
  sigma3 = flatten entries sigma3
  nonzerosing3 = position(0..#sigma3-2, i -> (sigma3#(i+1)/sigma3#i < 1.0e-10))
  sigma3#-1 / sigma3#-2 < 1.0e-10
    
  evs = Lp/SVD/first
  loc = 2
  vals = sort join(for a in evs#loc list (a,loc), for a in evs#(loc+1) list (a,loc+1))
  for i from 0 to #vals-2 list (
      if vals_i_1 != vals_(i+1)_1 then (
          abs(vals_i_0 - vals_(i+1)_0) / (vals_i_0 + vals_(i+1)_0), vals_i, vals_(i+1)
          )
      else null
      )      
  errs = select(oo, x -> x =!= null)
  netList oo
  select(errs, x -> x#0 < .1) -- 66
    select(errs, x -> x#0 < .01) -- 50 
    select(errs, x -> x#0 < .001) -- 47
  Cp = getNonminimalRes(C, Rp)
  C0 = getNonminimalRes(C, R0)
  Cp.dd^2
  C0.dd^2 -- TODO: make it so we can "clean" the results here.
///

TEST ///
restart
  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"
  I = getAGR(6,9,50,0);
  R = ring I
  elapsedTime C = res(I, FastNonminimal=>true)

  betti C
  elapsedTime SVDBetti C  

  Rp = (ZZ/32003)(monoid R)
  Ip = ideal sub(gens I, Rp);
  elapsedTime minimalBetti Ip
  elapsedTime Cp = res(Ip, FastNonminimal=>true)
///

TEST ///
restart
  -- ZZZZ
  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"

  I = value get "agr-6-7-37-0.m2";
  makeAGR(6,7,50,0)
  
  I = getAGR(6,7,50,0);
{*  
  R = QQ[a..h]
  deg = 6
  nextra = 30
  F = sum(gens R, x -> x^deg) + sum(nextra, i -> (randomForm(1,R))^deg);
  elapsedTime I = ideal fromDual matrix{{F}};
*}
  
  elapsedTime C = res(I, FastNonminimal=>true)
  betti C
  elapsedTime SVDBetti C  

  Rp = (ZZ/32003)(monoid R)
  Ip = ideal sub(gens I, Rp);
  elapsedTime minimalBetti Ip
  
  D = constantStrand(C, RR_53, 7)
  SVDComplex D;
  E = target first oo
  for i from 2 to 5 list sort flatten entries compress flatten E.dd_i
  Ls = constantStrands(C, RR_53)
///

TEST ///
restart
  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"

  elapsedTime makeAGR(7,7,100,32003)
  I = getAGR(7,7,100,32003);

  elapsedTime minimalBetti I
    
///

TEST ///
  -- warning: this currently requires test code on res2017 branch.
  -- XXXX
restart
  needsPackage "FreeResolutions"
  R = QQ[a..g]
  deg = 6
  nextra = 10
  nextra = 30
  --F = randomForm(deg, R)
  F = sum(gens R, x -> x^deg) + sum(nextra, i -> (randomForm(1,R))^deg);
  elapsedTime I = ideal fromDual matrix{{F}};
  elapsedTime C = res(I, FastNonminimal=>true)

  kk = ZZ/32003
  Rp = kk(monoid R)
  Ip = sub(I,Rp);
  elapsedTime minimalBetti Ip
  R0 = (RR_53) (monoid R)

  Ls = constantStrands(C,RR_53)  
  netList oo
  Lps = constantStrands(C,kk)
  debug Core
  kkflint = ZZp(32003, Strategy=>"Ffpack")
  Lps = constantStrands(C,kkflint)
  Lp = Lps_5
  L = Ls_5
  for i from 3 to 6 list elapsedTime first SVD L.dd_i  
  for i from 3 to 6 list rank mutableMatrix Lp.dd_i
  Lp = laplacians L;
  --Lp/eigenvalues
  evs = Lp/SVD/first
  loc = 2
  vals = sort join(for a in evs#loc list (a,loc), for a in evs#(loc+1) list (a,loc+1))
  for i from 0 to #vals-2 list (
      if vals_i_1 != vals_(i+1)_1 then (
          abs(vals_i_0 - vals_(i+1)_0) / (vals_i_0 + vals_(i+1)_0), vals_i, vals_(i+1)
          )
      else null
      )      
  errs = select(oo, x -> x =!= null)
  netList oo
  select(errs, x -> x#0 < .1) -- 66
    select(errs, x -> x#0 < .01) -- 50 
    select(errs, x -> x#0 < .001) -- 47
  Cp = getNonminimalRes(C, Rp)
  C0 = getNonminimalRes(C, R0)
  Cp.dd^2
  C0.dd^2 -- TODO: make it so we can "clean" the results here.
///


TEST ///
  -- warning: this currently requires test code on res2017 branch.
  -- XXXX
restart
  needsPackage "FreeResolutions"
  needsPackage "AGRExamples"
  deg = 6
  nv = 7
  nextra = binomial(nv + 1, 2) - nv - 10
  R = QQ[vars(0..nv-1)]


  --F = randomForm(deg, R)
  F = sum(gens R, x -> x^deg) + sum(nextra, i -> (randomForm(1,R))^deg);
  elapsedTime I = ideal fromDual matrix{{F}};
  elapsedTime C = res(I, FastNonminimal=>true)

  kk = ZZ/32003
  Rp = kk(monoid R)
  Ip = sub(I,Rp);
  elapsedTime Cp = res(Ip, FastNonminimal=>true)
  elapsedTime minimalBetti Ip
  R0 = (RR_53) (monoid R)
  SVDBetti C
  
  Ls = constantStrands(C,RR_53)  
  mats = flatten for L in Ls list (
      kf := keys L.dd;
      nonzeros := select(kf, k -> instance(k,ZZ) and L.dd_k != 0);
      nonzeros/(i -> L.dd_i)
      );
  elapsedTime(mats/(m -> first SVD m))
  netList oo
  Lps = constantStrands(C,kk)
  debug Core
  kkflint = ZZp(32003, Strategy=>"Ffpack")
  Lps = constantStrands(C,kkflint)
  Lp = Lps_5
  L = Ls_5
  for i from 3 to 6 list rank mutableMatrix Lp.dd_i
  Lp = laplacians L;
  --Lp/eigenvalues
  evs = Lp/SVD/first
  loc = 2
  vals = sort join(for a in evs#loc list (a,loc), for a in evs#(loc+1) list (a,loc+1))
  for i from 0 to #vals-2 list (
      if vals_i_1 != vals_(i+1)_1 then (
          abs(vals_i_0 - vals_(i+1)_0) / (vals_i_0 + vals_(i+1)_0), vals_i, vals_(i+1)
          )
      else null
      )      
  errs = select(oo, x -> x =!= null)
  netList oo
  select(errs, x -> x#0 < .1) -- 66
    select(errs, x -> x#0 < .01) -- 50 
    select(errs, x -> x#0 < .001) -- 47
  Cp = getNonminimalRes(C, Rp)
  C0 = getNonminimalRes(C, R0)
  Cp.dd^2
  C0.dd^2 -- TODO: make it so we can "clean" the results here.
///

beginDocumentation()

end--

doc ///
Key
  FreeResolutions
Headline
Description
  Text
  Example
Caveat
SeeAlso
///

doc ///
Key
Headline
Usage
Inputs
Outputs
Consequences
Description
  Text
  Example
  Code
  Pre
Caveat
SeeAlso
///

TEST ///
-- test code and assertions here
-- may have as many TEST sections as needed
///



-- Example 1
XXXXXXXXXXX
restart
debug needsPackage "FreeResolutions"
R = ZZ/101[a..e]
I = ideal"abc-cde,a2c-b2d,ade-cb2"
J = ideal gens gb I
(P0,P1) = makeFrameFromPolynomials J_*
Ps = makeFrames(P0,P1)

D = makeResolutionData(Ps)
makeMatrix(2,4,D)
makeMatrix(2,5,D)
makeMatrix(2,6,D)
makeMatrix(2,7,D)
makeMatrix(2,8,D)
degrees(3,D)
makeMatrix(3,7,D)
makeMatrix(3,8,D)
makeMatrix(3,9,D)
degrees(4,D)
makeMatrix(4,9,D)
degrees(5,D)
degrees(6,D)

betti D

degrees(1,D)
degrees(2,D)
M1 = getMatrix(1,D)
M2 = getMatrix(2,D)
  M22 = getMatrix(2,4,4,D)
  M22 = getMatrix(2,4,3,D)  
M1 * M2
M3 = getMatrix(3,D)
M2 * M3
M4 = getMatrix(4,D)
M3 * M4



for t in D.Frame#2 do processRow(t#LeadTerm, 2, D)
for r in D.RowList list (
    -- get the row monomials, and coeffs
    -- apply lookup, set the elemnts of the row as appropriate
    )
spairs = for i from 0 to 13 list Ps#2#i . LeadTerm
SP = for sp in spairs list getImage(sp, 2, D)
for sp in SP list monomialLookup(sp, D)

debug FreeResolutions
netList toList D.RowList
peek D.MonomialHashTable

findModuleMonomial(Ps#0,Ps#1,moduleMonomial(b^3*c^3*d,0))

findModuleMonomial(Ps#0,Ps#1,moduleMonomial(a*b^2*c,0))
findModuleMonomial(Ps#0,Ps#1,moduleMonomial(b*c*d*e,0))
findModuleMonomial(Ps#0,Ps#1,moduleMonomial(a^2*b*c,0))
findModuleMonomial(Ps#0,Ps#1,moduleMonomial(b^3*d,0))
findModuleMonomial(Ps#0,Ps#1,moduleMonomial(a^2*d*e,0))

Ps#1
Ps#2
P2 = nextFrame(P0,P1)
P3 = nextFrame(P1,P2)
P4 = nextFrame(P2,P3)
netList leadTerm P1
netList leadTerm P0
net P0
net P1
-- Example 2
YYYYYYYYYYYY
restart
debug needsPackage "FreeResolutions"
load "g16n2.m2"
J = ideal groebnerBasis(I, Strategy=>"F4");
J = ideal sort(gens J, MonomialOrder=>Descending, DegreeOrder=>Ascending);
(P0,P1) = makeFrameFromPolynomials J_*;
elapsedTime Ps = makeFrames(P0,P1);
D = makeResolutionData(Ps);
degrees(2,D)
degrees(3,D)
degrees(4,D)
-- first strand:
elapsedTime makeMatrix(2,3,D);
  rank getMatrix(2,3,3,D)
elapsedTime makeMatrix(3,4,D);
  elapsedTime rank elapsedTime getMatrix(3,4,4,D)
elapsedTime makeMatrix(4,5,D);

elapsedTime makeMatrix(2,4,D);


elapsedTime makeMatrix(3,5,D);


elapsedTime makeMatrix(4,6,D);


inJ = ideal leadTerm gens J
inJ2 = sort(gens inJ, MonomialOrder=>Descending, DegreeOrder=>Ascending)


-------------------
ZZZZZZZZZ
restart
debug needsPackage "FreeResolutions"
kk = ZZ/32003
R = kk[a..f]
I = ideal(e^2-1950*a*f-10835*b*f+19*c*f+6967*d*f+471*e*f+11482*f^2,
    d*e-4153*a*f-14463*b*f+3753*c*f-9438*d*f+1852*e*f-7402*f^2,
    c*e-13313*a*f+7574*b*f+3723*c*f+7768*d*f-2078*e*f-8028*f^2,
    b*e+1562*a*f-5172*b*f+1579*c*f+10666*d*f-14377*e*f+1206*f^2,
    a*e+13953*a*f-13529*b*f+12169*c*f+9295*d*f-3373*e*f-10190*f^2,
    d^2-4296*a*f+1019*b*f-11558*c*f+10583*d*f+14140*e*f-11542*f^2,
    c*d+12549*a*f-7879*b*f+6209*c*f-1679*d*f+12382*e*f+4322*f^2,
    b*d+4799*a*f-14761*b*f+10505*c*f+777*d*f-15307*e*f+7747*f^2,
    a*d+11450*a*f+5277*b*f+1201*c*f-2171*d*f-673*e*f-4936*f^2,
    c^2+1559*a*f-11074*b*f+6744*c*f+11458*d*f-9666*e*f+14902*f^2,
    b*c-7602*a*f-885*b*f-1455*c*f-10716*d*f+15330*e*f-8343*f^2,
    a*c-4035*a*f-11483*b*f-1225*c*f-9754*d*f-5280*e*f-7065*f^2,
    b^2+720*a*f-3277*b*f-1638*c*f-7205*d*f-2605*e*f-13781*f^2,
    a*b-12997*a*f-15389*b*f+1197*c*f+2206*d*f+4151*e*f-15246*f^2,
    a^2+8500*a*f-522*b*f+16001*c*f+11291*d*f+10250*e*f+13604*f^2)
J = ideal sort(gens gb I, MonomialOrder=>Descending, DegreeOrder=>Ascending);
(P0,P1) = makeFrameFromPolynomials J_*;
elapsedTime Ps = makeFrames(P0,P1);
D = makeResolutionData(Ps);
betti D
degrees(1,D)
degrees(2,D)
degrees(3,D)
degrees(4,D)
degrees(5,D)
degrees(6,D)
degrees(7,D) -- nothing here

-- linear strand
elapsedTime makeMatrix(2,3,D);
elapsedTime makeMatrix(3,4,D);
elapsedTime makeMatrix(4,5,D);
elapsedTime makeMatrix(5,6,D);
elapsedTime makeMatrix(6,7,D); -- 0 by 0

-- quadratic strand
elapsedTime makeMatrix(2,4,D);
elapsedTime makeMatrix(3,5,D);
elapsedTime makeMatrix(4,6,D);
elapsedTime makeMatrix(5,7,D);
elapsedTime makeMatrix(6,8,D); -- 0 by 0

getMatrix(2,4,4,D)
rank getMatrix(3,5,5,D)
rank getMatrix(4,6,6,D)
rank getMatrix(5,7,7,D)
rank getMatrix(6,8,8,D)
rank getMatrix(7,9,9,D)

elapsedTime makeMatrix(2,4,D);


getMatrix(2,3,3,D)
getMatrix(3,4,4,D)
rank getMatrix(4,5,5,D)
rank getMatrix(5,6,6,D)

getMatrix(2,4,4,D)

M1 = getMatrix(1,D)
M2 = getMatrix(2,D)
M1 * M2
M3 = getMatrix(3,D)
M2 * M3
M4 = getMatrix(4,D)
M3 * M4

-- Examples -- these are now elsewhere, or they should be.

AGRExample = method()
AGRExample(ZZ,ZZ,ZZ,Ring) := (n,d,s,kk) -> (
    x := getSymbol "x";
    R := kk[x_0..x_n];
    F := sum for i from 1 to s list (random(1,R))^d;
    trim sum for i from 1 to d list (
        B := basis(i,R);
        G := diff(transpose B, matrix{{F}});
        M := monomials flatten G;
        cfs := contract(transpose M, transpose G);
        ideal(B * (syz cfs))
        )
    )
AGRExample(ZZ,ZZ,ZZ) := (n,d,s) -> AGRExample(n,d,s,ZZ/10007)

CNC = method()
CNC(ZZ, Ring) := (g,kk) -> (
    )
CNC ZZ := (g) -> CNC(g, ZZ/32003)

