import java.util.Arrays;
import java.util.Scanner;

public class ReadAndGrowArray {
	public static void main(String[] args) {
		String[] names = new String[10];/*@\label{lineNames}@*/		
		Scanner in = new Scanner(System.in);
		int n = 0;
		String name = null;
		
		while (in.hasNextLine()) {
			name = in.nextLine();
			try {
				names[n] = name;
			}
			catch( ArrayIndexOutOfBoundsException e ) {/*@\label{exceptionRAGA}@*/
				names = Arrays.copyOfRange(names, 0,/*@\label{lineCopy}@*/
							names.length*2);
				names[n] = name;
			}
			n++;
		}
		
		Arrays.sort(names, 0, n);
		
		for (int i = 0; i < n; i++)
			System.out.println(names[i]);
	}
}