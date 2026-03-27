function midi=freq2midi(fq)
midi=log2(fq/440)*12 + 69;
