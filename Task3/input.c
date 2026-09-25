int sum(int first, int second){
	return first + second;
}

int main(){
	int result, values[3];
	float average;

	result = sum(4, 6);
	values[0] = result;
	average = values[0] / 2.0;
	printf(result);
	return 0;
}
