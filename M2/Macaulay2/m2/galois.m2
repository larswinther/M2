--		Copyright 1996-2002 by Daniel R. Grayson

GaloisField = new Type of EngineRing
GaloisField.synonym = "Galois field"

toExternalString GaloisField := k -> toString expression k
toString GaloisField := k -> (
     if ReverseDictionary#?k then toString ReverseDictionary#k
     else toExternalString k)
net GaloisField := k -> (
     if ReverseDictionary#?k then toString ReverseDictionary#k
     else net expression k)

ambient GaloisField := Ring => R -> last R.baseRings
coefficientRing GaloisField := Ring => R -> coefficientRing last R.baseRings

expression(GaloisField) := F -> new FunctionApplication from { GF, F.order }

GF = method (
     Options => { 
	  PrimitiveElement => FindOne,
	  Variable => null
	  }
     )

lastp := 2

unpack := (S,cont) -> (			  -- a quotient ring
     if class S =!= QuotientRing
     then error("expected ",toString S," to be a quotient ring");
     R := ultimate(ambient, S);			  -- original poly ring
     if R === ZZ then (
	  if isField S then (
	       R = S[local t];
	       S = R/t;
	       )
     	  else error("expected ",toString S," to be a field")
	  );
     if class R =!= PolynomialRing
     or numgens R =!= 1
     then error("expected ",toString R," to be a polynomial ring in one variable");
     if degreeLength R =!= 1
     then error("expected ",toString R," to be a simply graded polynomial ring");
     p := char R;
     if coefficientRing R =!= ZZ/p or (p =!= lastp and not isPrime p)
     then error("expected ",toString R," to be a polynomial ring over a finite prime field");
     lastp = p;
     I := presentation S;			  -- a Matrix, sigh
     if rank source I =!= 1
     then error("expected ",toString S," to be a quotient ring by a principal ideal");
     f := I_(0,0);
     n := first degree f;
     cont(R,p,n,f))

isPrimitive = (g) -> (
     g != 0 and
     unpack(ring g,
	  (R,p,n,f) -> (
     	       q := p^n;
     	       all(factor (q-1), v -> 1 != g ^ ((q-1)//v#0))
     	       )))

GF(ZZ,ZZ) := GaloisField => options -> (p,n) -> (
     if not isPrime p then error "expected a prime number as base";
     if n <= 0 then error "expected positive exponent";
     if n === 1 then ZZ/p
     else (
	  x := if options.Variable === null then symbol GF$a else baseName options.Variable;
	  R := ZZ/p[x];
	  t := R_0;
	  while ( f := t^n + sum(n, i-> random p * t^i); not isPrime f) do ();
	  GF(R/f,options,Variable => x)))

GF(ZZ) := GaloisField => options -> (q) -> (
     factors := factor q;
     if #factors =!= 1 or factors#0#0 === -1
     then error "expected a power of a prime";
     GF(factors#0#0,factors#0#1,options))

GF(Ring) := GaloisField => options -> (S) -> unpack(S, (R,p,n,f) -> (
     if not isPrime f
     then error("expected ",toString S," to be a quotient ring by an irreducible polynomial");
     primitiveElement := options.PrimitiveElement;
     if primitiveElement === FindOne then (
	  t := S_0;
	  if isPrimitive t then primitiveElement = t
	  else while ( 
	       primitiveElement = sum(n, i -> random p * t^i); 
	       not isPrimitive primitiveElement
	       ) do ())
     else (
	  if ring primitiveElement =!= S then error "expected primitive element in the right ring";
     	  if not isPrimitive primitiveElement then error "expected ring element to be primitive";
     	  );
     var := options.Variable;
     if var =!= null then var = baseName var
     else (
	  if primitiveElement === S_0 
	  then var = S.generatorSymbols#0
	  else var = symbol GF$a;
	  );
     d := p^n-1;
     rF := rawGaloisField raw primitiveElement;
     F := new GaloisField from rF;
     F.isBasic = true;
     toString F := h -> toString expression h;
     net F := h -> net expression h;
     F.baseRings = append(S.baseRings,S);
     F.isCommutative = true;
     expression F := t -> expression lift(t, S);
     F.degreeLength = 0;
     F.char = p;
     F.frac = F;
     F.generators = {};
     F.generatorSymbols = {};
     F.generatorExpressions = {};
     baseName F := y -> (
	  if F_0 == y then var else error "expected a generator"
	  );
     F.order = p^n;
     F / F := (x,y) -> x // y;
     F.use = F -> var <- F_0;
     F))

random GaloisField := F -> (
     i := random F.order;
     if i === 0 then 0_F else F_0^i
     )

dim GaloisField := R -> 0

isField GaloisField := F -> true
isField QuotientRing := R -> (
     R.?isField and R.isField
     or
     ambient R === ZZ and isPrime char R
     )
isField Ring := R -> (
     R.?isField and R.isField
     or
     R === QQ
     )

isAffineRing = method(TypicalValue => Boolean)
isAffineRing Ring := R -> isField R
isAffineRing PolynomialRing := R -> (
     not (options R).SkewCommutative and not (options R).Inverses and
     isAffineRing coefficientRing R
     )
isAffineRing QuotientRing := R -> isField R or isAffineRing ambient R


-- Local Variables:
-- compile-command: "make -C $M2BUILDDIR/Macaulay2/m2 "
-- End:
