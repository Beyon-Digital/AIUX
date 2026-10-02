//! `OrderedMap` — insertion-ordered, id-keyed store.
//!
//! Serializes as a JSON array in insertion order (deterministic for
//! conformance byte-compares); deserialization rebuilds the key index.
//! `BTreeMap` is used for the index so no `HashMap` iteration-order can ever
//! leak into output (plan §4).

use std::collections::BTreeMap;
use std::fmt;

use serde::de::{DeserializeOwned, SeqAccess, Visitor};
use serde::ser::SerializeSeq;
use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// Entities stored in an `OrderedMap` expose their id.
pub trait HasId {
    /// The entity's stable id.
    fn id(&self) -> &str;
}

/// Insertion-ordered map `id → entity`.
#[derive(Debug, Clone, PartialEq)]
pub struct OrderedMap<V> {
    order: Vec<String>,
    map: BTreeMap<String, V>,
}

impl<V> Default for OrderedMap<V> {
    fn default() -> Self {
        Self {
            order: Vec::new(),
            map: BTreeMap::new(),
        }
    }
}

impl<V: HasId> OrderedMap<V> {
    /// Insert or replace a value; new ids append to the order.
    pub fn insert(&mut self, value: V) {
        let id = value.id().to_string();
        if !self.map.contains_key(&id) {
            self.order.push(id.clone());
        }
        self.map.insert(id, value);
    }

    /// Whether the id exists.
    pub fn contains(&self, id: &str) -> bool {
        self.map.contains_key(id)
    }

    /// Borrow a value by id.
    pub fn get(&self, id: &str) -> Option<&V> {
        self.map.get(id)
    }

    /// Mutably borrow a value by id.
    pub fn get_mut(&mut self, id: &str) -> Option<&mut V> {
        self.map.get_mut(id)
    }

    /// Iterate in insertion order.
    pub fn iter(&self) -> impl Iterator<Item = &V> {
        self.order.iter().map(|id| &self.map[id])
    }

    /// Number of entries.
    pub fn len(&self) -> usize {
        self.map.len()
    }

    /// Whether the map is empty.
    pub fn is_empty(&self) -> bool {
        self.map.is_empty()
    }
}

impl<V: HasId + Serialize> Serialize for OrderedMap<V> {
    fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let mut seq = serializer.serialize_seq(Some(self.map.len()))?;
        for id in &self.order {
            seq.serialize_element(&self.map[id])?;
        }
        seq.end()
    }
}

impl<'de, V> Deserialize<'de> for OrderedMap<V>
where
    V: HasId + DeserializeOwned,
{
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct SeqVisitor<V>(std::marker::PhantomData<V>);
        impl<'de, V> Visitor<'de> for SeqVisitor<V>
        where
            V: HasId + DeserializeOwned,
        {
            type Value = OrderedMap<V>;

            fn expecting(&self, f: &mut fmt::Formatter) -> fmt::Result {
                f.write_str("an array of id-keyed entities")
            }

            fn visit_seq<A: SeqAccess<'de>>(self, mut seq: A) -> Result<Self::Value, A::Error> {
                let mut out = OrderedMap::default();
                while let Some(v) = seq.next_element::<V>()? {
                    out.insert(v);
                }
                Ok(out)
            }
        }
        deserializer.deserialize_seq(SeqVisitor(std::marker::PhantomData))
    }
}

macro_rules! has_id {
    ($ty:ty) => {
        impl HasId for $ty {
            fn id(&self) -> &str {
                &self.id
            }
        }
    };
}

has_id!(aiux_protocol::Message);
has_id!(aiux_protocol::Tool);
has_id!(aiux_protocol::Approval);
has_id!(aiux_protocol::Artifact);
has_id!(aiux_protocol::Surface);
has_id!(aiux_protocol::ContextEntity);
has_id!(aiux_protocol::Run);
