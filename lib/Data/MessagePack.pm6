use v6;
class Data::MessagePack {
    multi method pack( Any:U $object ) {
        Blob.new(0xc0);
    }
    multi method pack( Bool:D $b ) {
        $b??Blob.new(0xc3)!!Blob.new(0xc2);
    }

    multi method pack( Int:D $i ) {
        given $i {
            when * < -2**31 {
                my @segments;
                my $copy = $i;
                for (56, 48, 40, 32, 24 , 16, 8, 0) -> $e {
                    @segments.push( $copy div 2**$e );
                    $copy %= 2**$e;
                }
                return Blob.new( 0xd3, @segments );
            }
            when * < -2**15 {
                my @segments;
                my $copy = $i;
                for (24, 16, 8, 0) -> $e {
                    @segments.push( $copy div 2**$e );
                    $copy %= 2**$e;
                }
                return Blob.new( 0xd2, @segments );
            }
            when * < -2**7 { return Blob.new( 0xd1, $i div 256, $i % 256 )}
            when * < -32 { return Blob.new( 0xd0, $i ) }
            when * < 0 { return Blob.new( $i +& 255 ) }
            when * < 128 { return Blob.new( $i ) }
            when * < 2**8 { return Blob.new( 0xcc, $i ) }
            when * < 2**16 {
                #until i find a way to pack the value
                return Blob.new( 0xcd, $i div 256, $i % 256 );
            }
            when * < 2**32 {
                my @segments;
                my $copy = $i;
                for (24, 16, 8, 0) -> $e {
                    @segments.push( $copy div 2**$e );
                    $copy %= 2**$e;
                }
                return Blob.new( 0xce, @segments );
            }
            default {
                my @segments;
                my $copy = $i;
                for (56, 48, 40, 32, 24, 16, 8, 0) -> $e {
                    @segments.push( $copy div 2**$e );
                    $copy %= 2**$e;
                }
                return Blob.new( 0xcf, @segments );
            }
        }
    }

    multi method pack( Str:D $s ) {
        my $length = $s.chars;

        my @header;
        given $length {
            when $length < 32 { @header.push( 0xa0 + $length ) }
            when $length < 2**8 { @header.push( 0xd9, $length ) }
            when $length < 2**16 { @header.push( 0xda, $length +> 8 +& 0xff, $length +& 0xff ) }
            when $length < 2**32 { @header.push( 0xdb, $length +> 24 +& 0xff, $length +> 16 +& 0xff, $length +> 8 +& 0xff, $length +& 0xff ) }
            default { fail 'String is too long' }
        }
        return Blob.new(@header, $s.encode.list );
    }

    multi method pack( Blob:D $b ) {
        my $length = $b.elems;

        my @header;
        given $length {
            when $length < 2**8 { @header.push( 0xc4, $length ) }
            when $length < 2**16 { @header.push( 0xc5, $length +> 8 +& 0xff, $length +& 0xff ) }
            when $length < 2**32 { @header.push( 0xc6, $length +> 24 +& 0xff, $length +> 16 +& 0xff, $length +> 8 +& 0xff, $length +& 0xff ) }
            default { fail 'String is too long' }
        }
        return Blob.new(@header, $b.list );
    }

    multi method pack( Numeric:D $f ) {
        if $f.Int == $f {
            return self.pack( $f.Int );
        }
        #only double for now
        my $sign = $f>0??0!!1;
        my $abs = $f.abs;
        my $exp = ($abs.log / 2.log).Int;
        my $exp_bias = $exp + 1023;
        my $mantissa = $abs / 2**$exp;
        my $frac = $mantissa - 1;

        my $binary = $sign +< 63 +| $exp_bias +< 52 +| $frac * 2**52;

        return Blob.new( 0xcb, (56, 48 ... 0).map( $binary +> * +& 0xff) );
    }
};

# vim: ft=perl6
