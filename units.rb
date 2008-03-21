# currently unused, this is an experiment

class Float

  def usg
    self * 3.785411784
  end

  def impg
    self * 4.54609
  end

  def kg(sg = 0.72)
    self * sg
  end

  def l(sg = 0.72)
    self / sg
  end

end

class Unit < Float
end

class Litre < Unit

 def usg
    USGallon.new(self * 3.785411784)
  end

  def impg
    ImperialGallon.new(self * 4.54609)
  end

  def kg(sg = 0.72)
    Kilogram.new(self * sg)
  end

end

class USGallon < Unit
end

class ImperialGallon < Unit
end

class Kilogram < Unit
end 