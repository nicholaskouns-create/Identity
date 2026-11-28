theorem nested_factor {X Y : Type} (p s : X → X) (F : X → Y)
    (hp : ∀ x, F x = F (p x)) (hs : ∀ x, F x = F (s x))
    (x : X) : F x = F (s (p x)) := (hp x).trans (hs (p x))
