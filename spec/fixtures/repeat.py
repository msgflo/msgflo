#!/usr/bin/env python

import sys, os, json
sys.path.append(os.path.abspath("."))

import logging

import gevent
import gevent.event

from haigha.connection import Connection as haigha_Connection
from haigha.message import Message as haigha_Message

def addDefaultQueue(p, role):
  defaultQueue = '%s.%s' % (role, p['id'].upper())
  p.setdefault('queue', defaultQueue)
  return p

def normalizeDefinition(d, role):
  # Apply defaults
  d.setdefault('icon', 'file-word-o')
  d.setdefault('label', "")
  inports = d.setdefault('inports', [
      { 'id': 'in', 'type': 'any' }
  ])
  outports = d.setdefault('outports', [
      { 'id': 'out', 'type': 'any' }
  ])
  inports = [addDefaultQueue(p, role) for p in inports]
  outports = [addDefaultQueue(p, role) for p in outports]

  return d

class Participant:
  def __init__(self, d, role):
    self.definition = normalizeDefinition(d, role)

  def send(self, outport, outdata):
    if not self._runtime:
      return
    self._runtime._send(outport, outdata)

  def process(self, inport, inmsg):
    raise NotImplementedError('IParticipant.process()')

def sendParticipantDefinition(channel, d):
  msg = haigha_Message(json.dumps(d))
  channel.basic.publish(msg, '', 'fbp')
  print 'sent discovery message', msg
  return

def setupQueue(part, channel, direction, port):
  queue = port['queue']

  def handleInput(msg):
    print "Received message: %s" % (msg,)
    sys.stdout.flush()

    msg.data = json.loads(msg.body.decode("utf-8"))
    part.process(port, msg)
    # FIXME: ACK / NACK
    return

  if 'in' in direction:
    channel.queue.declare(queue)
    channel.basic.consume(queue=queue, consumer=handleInput)
    print 'subscribed to', queue
    sys.stdout.flush()
  else:
    channel.exchange.declare(queue, 'fanout')
    print 'created outqueue', queue
    sys.stdout.flush()

class GeventEngine(object):

  def __init__(self, participant, done_cb):
    self._done_cb = done_cb
    self.participant = participant
    self.participant._runtime = self

    # Connect to AMQP broker with default connection and authentication
    # settings (assumes broker is on localhost)
    self._conn = haigha_Connection(transport='gevent',
                                   close_cb=self._connection_closed_cb,
                                   logger=logging.getLogger())

    # Start message pump
    self._message_pump_greenlet = gevent.spawn(self._message_pump_greenthread)

    # Create message channel
    self._channel = self._conn.channel()
    self._channel.add_close_listener(self._channel_closed_cb)

    sendParticipantDefinition(self._channel, self.participant.definition)

    # Create and configure message exchange and queue
    for p in self.participant.definition['inports']:
      setupQueue(self.participant, self._channel, 'in', p)
    for p in self.participant.definition['outports']:
      setupQueue(self.participant, self._channel, 'out', p)

  def _send(self, outport, data):
    ports = self.participant.definition['outports']
    print "Publising message: %s, %s, %s" % (data,outport,ports)
    sys.stdout.flush()
    serialized = json.dumps(data)
    msg = haigha_Message(serialized)
    port = [p for p in ports if outport == p['id']][0]
    self._channel.basic.publish(msg, port['queue'], '')
    return
  
  def _message_pump_greenthread(self):
    try:
      while self._conn is not None:
        # Pump
        self._conn.read_frames()
        # Yield to other greenlets so they don't starve
        gevent.sleep()
    finally:
      self._done_cb()
    return 
  
  def _channel_closed_cb(self, ch):
    print "AMQP channel closed; close-info: %s" % (
      self._channel.close_info,)
    self._channel = None
    
    # Initiate graceful closing of the AMQP broker connection
    self._conn.close()
    return
  
  def _connection_closed_cb(self):
    print "AMQP broker connection closed; close-info: %s" % (
      self._conn.close_info,)
    self._conn = None
    return


class Repeat(Participant):
  def __init__(self, role):
    d = {
      'component': 'PythonRepeat',
      'id': role,
    }
    Participant.__init__(self, d, role)

  def process(self, inport, msg):
    self.send('out', msg.data)
    # TODO> support ACK/NACK


def main():
  waiter = gevent.event.AsyncResult()
  
  p = Repeat('repeat')
  GeventEngine(p, waiter.set)
  
  print "Running"
  sys.stdout.flush()
  waiter.wait()
  print "Shutdown"
  sys.stdout.flush()

  return

if __name__ == '__main__':
  logging.basicConfig()
  main()

