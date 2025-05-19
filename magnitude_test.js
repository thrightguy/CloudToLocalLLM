// A simple Magnitude test case
module.exports = {
  name: 'Simple Calculator Test',
  description: 'Tests basic calculator operations through a simple UI',
  steps: [
    {
      name: 'Add two numbers',
      task: 'Add 5 and 3 to get 8',
      expected: 'The result should be 8',
    },
    {
      name: 'Subtract numbers',
      task: 'Subtract 2 from 10 to get 8',
      expected: 'The result should be 8',
    },
    {
      name: 'Multiply numbers',
      task: 'Multiply 4 and 2 to get 8',
      expected: 'The result should be 8',
    },
  ],
};
