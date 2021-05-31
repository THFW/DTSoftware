
void g()
{
}

int func(int a, int b)
{
    g();
    a = a + b;
    return a;
}

int main()
{
    func(1, 2);
    return 0;
}